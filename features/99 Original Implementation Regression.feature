@domain.sd @regression
Feature: Original Implementation Regression
  As a Federated Catalogue operator
  I want to verify the original server behavior with strict validation
  So that schema enforcement and Gaia-X compliance work as designed

  # Original server config (2.0.0 image):
  #   schema=true, semantics=true, vp-signature=true, vc-signature=true
  #   Gaia-X trust framework always enabled (no toggle in 2.0.0)
  #
  # Signature fixtures use did:jwk (resolved via Universal Resolver).
  # Requires: uni-resolver-client >= 0.51.0 (patched from broken 0.35.0).
  # See: fixture-signing.md in bdd-automation-knowledge/

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  # --- Schema validation (server default: schema=true) ---

  @smoke @cfg.schema-val
  Scenario: Minimal Participant passes schema validation on original server
    # The core#Participant fixture conforms to loaded SHACL shapes.
    # Schema=true is active but the shapes are permissive for this type.
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 200:Success code

  @cfg.schema-val
  Scenario: Structurally invalid payload rejected with schema validation enabled
    When verify self-description
      """
      { "invalid": "payload" }
      """
    Then get http 422:Unprocessable Entity code

  # --- Gaia-X Trust Framework compliance (gaiax.enabled=true) ---

  @smoke @cfg.gaiax
  Scenario: Verification passes with gaiax enabled but no compliance VC
    # FINDING: gaiax.enabled=true does NOT enforce compliance check on /verification.
    # The trust framework check is only enforced during upload (/self-descriptions).
    # Verification endpoint returns 200 even without a Gaia-X compliance credential.
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 200:Success code

  # --- Signature verification (server default: signatures=true) ---

  @smoke @cfg.test-sig
  Scenario: Verification with valid signatures passes on original server
    # Fixture signed with JsonWebSignature2020 + did:jwk.
    # DID resolved via Universal Resolver (no local did-server needed).
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.signed.jsonld"
    Then get http 200:Success code

  # --- Upload with strict validation ---

  @cfg.original
  Scenario: Upload rejects credential with unresolvable signatures
    # Unsigned fixture has Ed25519 test proofs — server cannot resolve the DIDs.
    When add self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld"
    Then get http 422:Unprocessable Entity code

  @smoke @cfg.gaiax @cfg.test-sig
  Scenario: Upload with valid signatures succeeds on original server
    # Full end-to-end: signature verification + trust anchor + schema + semantics → 201.
    # Cleanup any leftover from previous runs to avoid 409 Conflict.
    Given self-description from fixture "valid/gaiax-participant-correct-type.vp.signed.jsonld" is not uploaded
    When add self-description from fixture "valid/gaiax-participant-correct-type.vp.signed.jsonld"
    Then get http 201:Created code