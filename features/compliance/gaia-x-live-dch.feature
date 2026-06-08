@uses.live-gxdch @domain.compliance @req.CAT-FR-CO-04 @cfg.gaiax
Feature: Gaia-X Live DCH Compliance Check
  As a Federated Catalogue operator
  I want to run compliance checks against the live Gaia-X Digital Clearing House (Loire v2)
  So that Gaia-X participants can obtain verifiable compliance attestations from the real DCH

  # These scenarios run against the Gaia-X Lab /development DCH generation.
  # /development accepts Let's Encrypt chain, so the
  # showcase (which signs with a Let's Encrypt did:web key) targets /development.
  #
  # These scenarios require:
  #   - A QA stage with internet access to the Gaia-X Lab /development endpoints
  #     (compliance.lab.gaia-x.eu/development, registry.lab.gaia-x.eu/development,
  #      registrationnumber.notary.lab.gaia-x.eu/development).
  #   - The gaia-x trust framework family enabled (Background) and its bundle repointed at the
  #     Lab /development endpoints (Background — overrides serviceUrl + trustAnchorUrl, auto-cleared).
  #   - A signing key with a publicly resolvable x5u certificate chain accepted by the Lab
  #     /development registry (self-signed local CA not sufficient). The showcase reuses the
  #     deployed did:web #0 Let's Encrypt key.
  #
  # Run with:
  #   behave --tags=uses.live-gxdch features/compliance/gaia-x-live-dch.feature
  #
  # NOT in default CI — tag-gated.

  Background:
    Given CAT Keycloak is up
    And saved Keycloak token
    And Federated Catalogue Server is up
    And Gaia-X trust framework is enabled
    And operator overrides bundle "gaia-x-2511" config: serviceUrl = "https://compliance.lab.gaia-x.eu/development"
    And operator overrides bundle "gaia-x-2511" config: trustAnchorUrl = "https://registry.lab.gaia-x.eu/development/api/trustAnchor/chain/file"

  @smoke
  Scenario: Loire-conformant asset passes Live DCH compliance check
    # Precondition: gaia-x family enabled + bundle repointed at the Lab /development DCH (Background).
    #
    # FIXTURE: fixtures/loire/valid/participant-vp.loire.dch-trusted.signed.jwt
    # — NOT committed (gitignored); provision per-QA with:
    #     python3 scripts/provision-gxdch-showcase.py --verify
    #   It mints a notary LRN (VAT BE0762747721, VIES-validated), self-signs a LegalPerson + T&C
    #   VC under the gaia-x/development# context, assembles a VP, and signs it with the deployed
    #   did:web #0 Let's Encrypt key (PS256). --verify asserts the Lab DCH issues an attestation.
    Given credential from fixture "loire/valid/participant-vp.loire.dch-trusted.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant-vp.loire.dch-trusted.signed.jwt" with content-type "application/vp+jwt"
    Then get http 201:Created code
    And save asset id from last response
    When run compliance check for saved asset with profile "gaia-x-2511" and credential from fixture "loire/valid/participant-vp.loire.dch-trusted.signed.jwt"
    Then get http 200:Success code
    And compliance result conforms is true
    And compliance result has attestation credential
    And save attestation credential from last compliance response
    When execute SPARQL query
      """
      PREFIX fcmeta: <https://w3id.org/gaia-x/fcmeta#>
      SELECT ?check ?profileId ?validUntil WHERE {
        ?check a fcmeta:ComplianceCheck ;
               fcmeta:frameworkProfileId ?profileId ;
               fcmeta:credentialValidUntil ?validUntil .
      }
      """
    Then query result contains "gaia-x-2511"
    And compliance check SPARQL result has credentialValidUntil set

  Scenario: Non-conformant asset fails Live DCH compliance check with UNVERIFIABLE_ATTESTATION
    # A VP signed with a non-DCH-trusted key will be rejected by the live DCH.
    # The JwtVcComplianceClient maps any DCH rejection (4xx) to UNVERIFIABLE_ATTESTATION.
    # Fixture: fixtures/loire/valid/participant-vp.loire.signed.jwt (local test key,
    # not trusted by real DCH — produces the expected rejection).
    Given credential from fixture "loire/valid/participant-vp.loire.signed.jwt" is not uploaded
    When add credential from fixture "loire/valid/participant-vp.loire.signed.jwt" with content-type "application/vp+jwt"
    Then get http 201:Created code
    And save asset id from last response
    When run compliance check for saved asset with profile "gaia-x-2511" and credential from fixture "loire/valid/participant-vp.loire.signed.jwt"
    Then get http 200:Success code
    And compliance result conforms is false
    And compliance result failure category is "UNVERIFIABLE_ATTESTATION"
