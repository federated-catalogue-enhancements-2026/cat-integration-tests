@domain.admin @req.CAT-FR-AU-01
Feature: Admin API — Runtime Configuration
  As a catalogue administrator
  I want to control asset type restriction, schema validation, and trust framework toggles at runtime
  So that the catalogue enforces the correct upload and verification policies without a restart

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  # ---------------------------------------------------------------------------
  # Asset Type Restriction
  # ---------------------------------------------------------------------------

  @smoke @cfg.default
  Scenario: Asset type restriction disabled — any credential type accepted
    # With restriction off, a VerifiablePresentation credential uploads without type filtering.
    Given asset type restriction is disabled
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code

  @baseline @cfg.default
  Scenario: Asset type restriction enabled — matching type accepted
    # VerifiablePresentation is in the allowlist → upload succeeds.
    Given asset type restriction is enabled with allowed types "VerifiablePresentation"
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
      And asset type restriction is reset to defaults

  @baseline @cfg.default
  Scenario: Asset type restriction enabled — non-matching type rejected
    # Allowlist contains only "SomeOtherType"; VerifiablePresentation is not allowed → 400.
    Given asset type restriction is enabled with allowed types "SomeOtherType"
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 400:Bad Request code
      And asset type restriction is reset to defaults

  @baseline @cfg.default
  Scenario: Asset type restriction enabled but empty — all uploads blocked
    # Restriction on with empty allowlist → every upload is rejected.
    Given asset type restriction is enabled with allowed types ""
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 400:Bad Request code
      And asset type restriction is reset to defaults

  # ---------------------------------------------------------------------------
  # Schema Validation Toggle
  # ---------------------------------------------------------------------------

  @baseline @cfg.default
  Scenario: SHACL module disabled via admin API — violating credential accepted
    # Disable SHACL via admin API; a credential that violates a stored shape must still upload.
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded
      And SHACL schema module is disabled
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld"
    Then get http 201:Created code
      And SHACL schema module is re-enabled
      And uploaded schemas are cleaned up

  @baseline @cfg.strict @cfg.test-sig
  Scenario: SHACL module re-enabled via admin API — violating credential rejected
    # Re-enable SHACL (default for strict); credential missing legalName is rejected.
    Given schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded
      And SHACL schema module is enabled
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.signed.jsonld"
    Then get http 422:Unprocessable Entity code
      And uploaded schemas are cleaned up

  # ---------------------------------------------------------------------------
  # Gaia-X Trust Framework Toggle
  # ---------------------------------------------------------------------------

  @smoke @cfg.default
  Scenario: Gaia-X trust framework disabled — compliance check skipped
    # With Gaia-X disabled, verification of a credential without compliance proof passes.
    Given Gaia-X trust framework is disabled
    When verify credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 200:Success code

  @baseline @cfg.strict @cfg.test-sig
  Scenario: Gaia-X trust framework enabled — credential with valid trust anchor accepted
    # Full Gaia-X validation: type check + x5u + Trust Anchor Registry call → 201.
    Given Gaia-X trust framework is enabled
      And credential from fixture "valid/gaiax-participant.vp.signed.jsonld" is not uploaded
    When add credential from fixture "valid/gaiax-participant.vp.signed.jsonld"
    Then get http 201:Created code
      And credential from fixture "valid/gaiax-participant.vp.signed.jsonld" is not uploaded

  @baseline @cfg.strict @cfg.test-sig
  Scenario: Gaia-X trust framework enabled — credential with unrecognized type rejected
    # Credential subject type (legacy participant# namespace) is not in the recognized base class URIs
    # → hasClasses() = false → 422 Unprocessable Entity.
    Given Gaia-X trust framework is enabled
    When add credential from fixture "valid/default-only/gaiax-participant-legacy-type.vp.signed.jsonld"
    Then get http 422:Unprocessable Entity code

  @baseline @cfg.strict @cfg.test-sig
  Scenario: Type restriction and SHACL active simultaneously — SHACL fires before type gate
    # Both restrictions active. SHACL rejects first (422) even when type restriction is set to block.
    # After relaxing type restriction to match the credential, SHACL still fires → 422.
    # Disabling SHACL with a matching type restriction → type gate blocks → 400.
    Given asset type restriction is disabled
      And SHACL schema module is enabled
      And uploaded schemas are cleaned up
      And schema from fixture "schemas/participant-requires-legalname.shacl.ttl" is uploaded
      And SHACL schema module is enabled
      And asset type restriction is enabled with allowed types "SomeOtherType"
      And credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.signed.jsonld" is not uploaded
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.signed.jsonld"
    Then get http 422:Unprocessable Entity code
    Given SHACL schema module is disabled
    When add credential from fixture "valid/default-only/gaiax-participant-correct-type.vp.signed.jsonld"
    Then get http 400:Bad Request code
      And asset type restriction is reset to defaults
      And SHACL schema module is re-enabled
      And uploaded schemas are cleaned up

  # ---------------------------------------------------------------------------
  # Admin Stats
  # ---------------------------------------------------------------------------

  @smoke @cfg.default
  Scenario: Admin stats endpoint returns all expected fields
    When request admin stats
    Then get http 200:Success code
      And response has admin stats fields
