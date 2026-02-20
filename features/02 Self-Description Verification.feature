@domain.verify @baseline
Feature: Self-Description Verification
  As a Federated Catalogue API consumer
  I want to verify a Self-Description
  So that I can check its validity before submitting it

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  # Smoke test: fixture uses legacy @type (http://w3id.org/gaia-x/participant#Participant)
  # which does not match any loaded ontology — server rejects with semantic error.
  @smoke @cfg.no-schema-val @cfg.test-sig
  Scenario: Verify SD with unrecognised type returns semantic error
    When verify self-description from fixture "valid/gaiax-participant.vp.jsonld"
    Then get http 422:Unprocessable Entity code

  @smoke @req.CAT-FR-CO-01 @gate.CO1 @cfg.no-schema-val @cfg.test-sig
  Scenario: Verify SD with correct ontology type passes semantic check
    # Uses fixture with @type matching loaded ontology (https://w3id.org/gaia-x/core#Participant).
    # Signatures are skipped because the fixture contains test-only Ed25519 proofs.
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 200:Success code

  @smoke @cfg.no-schema-val
  Scenario: Verify an invalid Self-Description returns error
    When verify self-description
      """
      { "invalid": "payload" }
      """
    Then get http 422:Unprocessable Entity code