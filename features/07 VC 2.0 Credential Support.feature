@domain.asset @req.CAT-FR-GD-01
Feature: VC 2.0 Credential Support
  As a Federated Catalogue API consumer
  I want to upload Verifiable Credentials in VC 2.0 format
  So that the catalogue accepts both VC 1.1 and VC 2.0 ecosystems

  # Default server config: verifyVCSignatures=false, verifyVPSignatures=false
  # VC 2.0 uses "validFrom" instead of "issuanceDate" and the v2 context URI.
  # JWT detection is body-based (starts with "eyJ") — no special content-type required.

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  @smoke @cfg.default
  Scenario: Upload a standalone VC 2.0 credential
    # VC 2.0 uses "validFrom" and https://www.w3.org/ns/credentials/v2 context.
    # With signature verification disabled, upload must succeed with 201.
    Given credential from fixture "vc20/valid/participant.vc2.jsonld" is not uploaded
    When add credential from fixture "vc20/valid/participant.vc2.jsonld"
    Then get http 201:Created code

  @smoke @cfg.default
  Scenario: Upload a VC 2.0 credential wrapped in a Verifiable Presentation
    # VP2 wraps a VC 2.0 credential — existing VP processing path handles this.
    Given credential from fixture "vc20/valid/participant.vp2.jsonld" is not uploaded
    When add credential from fixture "vc20/valid/participant.vp2.jsonld"
    Then get http 201:Created code

  @cfg.default
  Scenario: Upload a JWT-wrapped VC 2.0 credential
    # JWT credentials must be submitted with Content-Type: application/vc+ld+json+jwt.
    # Sending a JWT body with a JSON-LD content-type (e.g. application/vc+ld+json) is rejected with 400.
    # "vc" claim contains the VC 2.0 object; signature not verified in default config.
    Given credential from fixture "vc20/valid/participant.vc2.jwt" is not uploaded
    When add credential from fixture "vc20/valid/participant.vc2.jwt" with content-type "application/vc+ld+json+jwt"
    Then get http 201:Created code

  @cfg.default
  Scenario: JWT body submitted with JSON-LD content-type is rejected
    When add credential from fixture "vc20/valid/participant.vc2.jwt" with content-type "application/vc+ld+json"
    Then get http 400:Bad Request code

  @cfg.default
  Scenario: JSON-LD body submitted with JWT content-type is rejected
    When add credential from fixture "vc20/valid/participant.vc2.jsonld" with content-type "application/vc+ld+json+jwt"
    Then get http 400:Bad Request code

  @cfg.default
  Scenario: Upload a JWT-wrapped credential with VP JWT content-type is accepted
    # Covers AC 2: application/vp+ld+json+jwt positive path.
    # TODO: replace fixture with a proper VP JWT once participant.vp2.jwt exists.
    Given credential from fixture "vc20/valid/participant.vc2.jwt" is not uploaded
    When add credential from fixture "vc20/valid/participant.vc2.jwt" with content-type "application/vp+ld+json+jwt"
    Then get http 201:Created code

  @cfg.default
  Scenario: VC 2.0 credential with expired validUntil is rejected
    # "validUntil" set to a past date — server must reject with 422.
    When add credential from fixture "vc20/invalid/participant-expired.vc2.jsonld"
    Then get http 422:Unprocessable Entity code

  @smoke @regression @cfg.default
  Scenario: VC 1.1 credential continues to be accepted after VC 2.0 support added
    # Backward compatibility: VC 1.1 fixture with "issuanceDate" must still succeed.
    Given credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
