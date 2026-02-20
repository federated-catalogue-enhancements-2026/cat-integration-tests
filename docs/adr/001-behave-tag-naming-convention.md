# ADR-001: Behave Tag Naming Convention

- **Status:** Accepted
- **Date:** 2026-02-20
- **Context:** FACIS-FCE Federated Catalogue BDD test suite (`cat-integration-tests`)

## Problem

The Federated Catalogue is a configurable system. Different deployments run with different
graph database backends (Neo4j vs Fuseki), different validation policies (forced schema
validation vs on-demand), different trust frameworks (Gaia-X enabled vs disabled), and
different messaging infrastructure. Each configuration variant requires its own subset of
tests to be executed in CI.

At the same time, the FACIS Inspection and Approval process (ref: `01-input/2.0
FACIS_FCE_Inspection_and_Approval.pdf`) defines **7 acceptance gates**, each grouping
multiple SRS requirements. Tests must be traceable to individual requirement IDs and
to the gate they belong to for evidence collection per gate.

Additionally, the catalogue has existing behaviour predating the FACIS requirements that
must continue to work — these "baseline" tests are not tied to any new requirement but
must still run in every configuration.

Without a disciplined naming scheme, tags will collide (e.g. `@schema` — is that the API
domain or the validation config?), CI filters will break silently, and traceability to
requirements will be lost.

## Decision

We adopt a **dot-separated hierarchical tag convention** with 6 dimensions. Each dimension
uses a unique prefix to guarantee disambiguation.

### Tag Dimensions

| Prefix | Dimension | Cardinality | Applied to | Purpose |
|--------|-----------|-------------|------------|---------|
| `@req.` | Requirement ID | 1:N per scenario | Scenarios | Traceability to SRS requirement |
| `@gate.` | Acceptance gate | 1:N per feature/scenario | Features or scenarios | Groups requirements per FACIS I&A gates |
| `@domain.` | API domain | 1 per feature | Features | Which API area is under test |
| `@cfg.` | Config variant | 0:N per scenario | Scenarios | Which deployment config is required |
| _(bare)_ | Test purpose | 1 per feature/scenario | Either | `@smoke`, `@baseline`, `@regression` |
| _(bare)_ | Dev utility | 0:1 | Scenarios | `@wip`, `@skip`, `@this` |

### Requirement Tags (`@req.`)

Format: `@req.CAT-FR-{category}-{number}`

```gherkin
@req.CAT-FR-CO-01  @req.CAT-FR-SF-04  @req.CAT-NFR-01
```

Every scenario that validates a specific SRS requirement MUST carry the corresponding
`@req.` tag. A scenario may carry multiple `@req.` tags if it covers several requirements.

### Gate Tags (`@gate.`)

Format: `@gate.{gate-id}`

| Tag | Gate | Requirements covered |
|-----|------|---------------------|
| `@gate.AM1` | Asset Management | CAT-FR-AM-01, -02, -03 |
| `@gate.GD1` | Claim Extraction to Graph DB | CAT-FR-GD-01, -02, -09 |
| `@gate.GD2` | Switchable Graph DB Backends | CAT-FR-GD-03, -04, -05, -06, -07, -08 |
| `@gate.AC1` | Access Control | CAT-FR-AC-01, -02 |
| `@gate.LS1` | Lifecycle and Storage | CAT-FR-LM-01 thru -04, CAT-FR-SF-01 thru -04 |
| `@gate.CO1` | Compliance, Trust, Validation | CAT-FR-CO-01, -02, -03, -04, -05 |
| `@gate.AU1` | Administration UI | CAT-FR-AU-01 |

Gates are typically applied at the feature level. A feature may span multiple gates if its
scenarios cover requirements from different gates.

### Domain Tags (`@domain.`)

Format: `@domain.{api-area}`

| Tag | API area | Endpoints |
|-----|----------|-----------|
| `@domain.sd` | Self-Descriptions | `/self-descriptions/*` |
| `@domain.verify` | Verification | `/verification` |
| `@domain.query` | Query | `/query/*` |
| `@domain.schema` | Schemas | `/schemas/*` |
| `@domain.participant` | Participants | `/participants/*` |
| `@domain.user` | Users | `/users/*` |
| `@domain.session` | Session | `/session` |
| `@domain.role` | Roles | `/roles` |
| `@domain.auth` | Authentication | Keycloak token flow |

Applied once per feature file. Prevents collision with config tags (e.g. `@domain.schema`
is unambiguously the API domain, not the validation flag).

### Config Variant Tags (`@cfg.`)

Format: `@cfg.{variant}`

These tags declare **which deployment configuration a scenario requires**. CI pipelines
use them to select the correct subset for the currently deployed variant.

**Graph backend:**

| Tag | Meaning |
|-----|---------|
| `@cfg.neo4j` | Requires Neo4j backend (`graphstore.impl=neo4j`) |
| `@cfg.fuseki` | Requires Fuseki backend (`graphstore.impl=fuseki`) |

**Validation policy:**

| Tag | Meaning |
|-----|---------|
| `@cfg.forced-schema-val` | Requires `verification.schema=true` |
| `@cfg.no-schema-val` | Requires `verification.schema=false` (default after CAT-FR-SF-04) |

**Trust framework:**

| Tag | Meaning |
|-----|---------|
| `@cfg.gaiax` | Requires `trust-framework.gaiax.enabled=true` |
| `@cfg.no-gaiax` | Requires `trust-framework.gaiax.enabled=false` (default) |

**Signature verification:**

| Tag | Meaning |
|-----|---------|
| `@cfg.real-sig` | Requires real DID resolution and signature verification |
| `@cfg.test-sig` | Uses test fixtures with non-verifiable signatures (skip sig flags) |

Scenarios **without** any `@cfg.` tag are configuration-agnostic and run in every variant.

### Test Purpose Tags (bare, no prefix)

| Tag | Meaning |
|-----|---------|
| `@smoke` | Minimal happy-path coverage — runs in every CI pipeline |
| `@baseline` | Original catalogue behaviour that predates FACIS requirements |
| `@regression` | Full coverage — runs on merge to main |

### Dev Utility Tags (bare, no prefix)

| Tag | Meaning |
|-----|---------|
| `@wip` | Work in progress — excluded from CI |
| `@skip` | Temporarily disabled |
| `@this` | Developer focus tag for local runs |

## Example

```gherkin
@domain.verify @gate.CO1 @baseline
Feature: Self-Description Verification
  As a Federated Catalogue API consumer
  I want to verify a Self-Description
  So that I can check its validity before submitting it

  Background:
    Given CAT Keycloak is up
      And saved Keycloak token
      And Federated Catalogue Server is up

  @smoke @cfg.no-schema-val @cfg.test-sig
  Scenario: Verify SD with unrecognised type returns semantic error
    When verify self-description from fixture "valid/gaiax-participant.vp.jsonld"
    Then get http 422:Unprocessable Entity code

  @smoke @req.CAT-FR-CO-01 @cfg.no-schema-val @cfg.test-sig
  Scenario: Verify SD with correct ontology type passes semantic check
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 200:Success code

  @smoke @cfg.no-schema-val
  Scenario: Verify an invalid Self-Description returns error
    When verify self-description
      """
      { "invalid": "payload" }
      """
    Then get http 422:Unprocessable Entity code

  @req.CAT-FR-SF-04 @cfg.forced-schema-val @cfg.test-sig
  Scenario: Verify SD with forced schema validation enabled
    When verify self-description from fixture "valid/gaiax-participant-correct-type.vp.jsonld" skipping signatures
    Then get http 422:Unprocessable Entity code
```

## CI Usage

```bash
# Smoke tests for the default config (Neo4j, no Gaia-X, no forced schema)
behave --tags="@smoke and not @cfg.fuseki and not @cfg.gaiax and not @cfg.forced-schema-val"

# All tests for Gate GD2 on Fuseki backend
behave --tags="@gate.GD2 and @cfg.fuseki"

# All tests for Gate CO1
behave --tags="@gate.CO1"

# Baseline regression — original behaviour
behave --tags="@baseline"

# Everything that runs on the default Neo4j config
behave --tags="not @cfg.fuseki and not @cfg.gaiax and not @cfg.forced-schema-val"
```

## Consequences

**Benefits:**
- Every tag dimension has a unique prefix — no naming collisions possible.
- `@req.` and `@gate.` give direct traceability to SRS requirements and FACIS I&A gates
  for evidence collection.
- `@cfg.` tags allow CI to deploy a specific catalogue configuration and run exactly the
  matching test subset, without maintaining separate feature files per variant.
- `@baseline` clearly separates pre-FACIS behaviour from new requirement coverage.
- New config dimensions (e.g. a future `@cfg.dch-reachable` for Gaia-X DCH dependency)
  can be added without touching existing tags.

**Trade-offs:**
- Dot-separated prefixes are more verbose than bare tags. This is deliberate — we
  prioritise disambiguation over brevity.
- Feature files may accumulate many tags on scenarios that span multiple requirements
  and config variants. This is acceptable because the tags serve as machine-readable
  metadata for CI and traceability, not prose.

## References

- FACIS Inspection and Approval Requirements (`01-input/2.0 FACIS_FCE_Inspection_and_Approval.pdf`) — gate definitions
- FACIS SRS — requirement IDs (`CAT-FR-*`)
- Behave tag expressions: https://behave.readthedocs.io/en/stable/tag_expressions.html