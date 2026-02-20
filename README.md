# CAT Integration Tests

BDD acceptance tests for the Eclipse XFSC Federated Catalogue, using the [bdd-executor](https://github.com/eclipse-xfsc/bdd-executor) framework (Python Behave).

## Prerequisites

- Python 3.12+
- Running Federated Catalogue docker-compose stack (see `federated-catalogue/docker/`)
- `127.0.0.1 key-server` in `/etc/hosts`
- Keycloak user with Federated Catalogue roles (see [Keycloak Setup](#keycloak-setup) below)

## Setup

```bash
# Configure environment
cp env.sample.sh env.sh
# Edit env.sh — set CAT_ENV to your target (docker-compose / minikube / qa)
source env.sh

# Install dependencies
# NOTE: EU_XFSC_BDD_CORE_PATH must point to the bdd-executor repo root.
# Default (../../) assumes cat-integration-tests lives inside bdd-executor/implementations/.
# When running from somewhere else, override this value (this example assumes that bdd-executor is a sibling dir):
EU_XFSC_BDD_CORE_PATH=../bdd-executor make setup_dev
```

## Running Tests

```bash
source env.sh

# Run all BDD features
make run_cat_bdd_dev

# Run with HTML report
make run_cat_bdd_dev_html

# Run code quality checks
make code_check
```

## Keycloak Setup

The tests authenticate via **Resource Owner Password Grant** (not client credentials). You need a Keycloak user with the correct Federated Catalogue roles.

### 1. Create a test user

1. Open Keycloak Admin Console: <http://key-server:8080/admin/> (admin / admin for docker-compose)
2. Select the **gaia-x** realm
3. Go to **Users** > **Add user**
4. Set username to `admin` (or whatever `CAT_TEST_USER` is set to in `env.sh`)
5. Save

### 2. Set a permanent password

1. Go to the user's **Credentials** tab
2. Click **Set password**
3. Enter the password matching `CAT_TEST_PASSWORD` in `env.sh` (default: `admin`)
4. Set **Temporary** to **OFF**
5. Save

### 3. Clear required actions

1. Go to the user's **Details** tab
2. Remove all entries from **Required User Actions** (e.g. "Update Password", "Verify Email")
3. Save

If required actions remain, the password grant will fail with: `invalid_grant: Account is not fully set up`.

### 4. Assign Federated Catalogue roles

1. Go to the user's **Role mapping** tab
2. Click **Assign role**
3. Filter by client: **federated-catalogue**
4. Assign the roles needed for your test scenarios:

| Role | Required for |
|------|-------------|
| `Ro-MU-CA` | Catalogue Admin (full access) |
| `Ro-MU-A` | User management |
| `Ro-SD-A` | Self-Description management (create, delete, revoke) |
| `Ro-PA-A` | Participant management |

For running all tests, assign **Ro-MU-CA** (includes all permissions).

### 5. Verify

```bash
# Quick check that the token grant works:
curl -s -X POST http://key-server:8080/realms/gaia-x/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=federated-catalogue" \
  -d "username=admin" \
  -d "password=admin" \
  -d "scope=openid" | python3 -m json.tool | head -5
```

You should see `"access_token": "eyJ..."` in the response.

## Environment Configuration

The `env.sh` file uses a `CAT_ENV` switch to target different deployments:

| Target | `CAT_ENV` | FC Host | Keycloak |
|--------|-----------|---------|----------|
| Docker Compose (local) | `docker-compose` | `http://localhost:8081` | `http://key-server:8080` |
| Minikube / k8s | `minikube` | `http://localhost:30081` | `http://localhost:30080` |
| QA / Staging | `qa` | configurable | configurable |

## Project Structure

```
features/                    # Gherkin .feature files
steps/                       # Behave step definitions
  keycloak.py                #   Auth steps (CatKeycloakServer — password grant)
  fc_server.py               #   FC API steps (CRUD, verify, query, etc.)
  rest.py                    #   Additional HTTP status assertions (422)
src/eu/xfsc/bdd/cat/        # Shared Python package
  env.py                     #   OS env var bindings
  defaults.py                #   Constants (PREFIX="CAT")
  components/
    fc_server.py             #   Server wrapper (BaseServiceKeycloak)
    keycloak.py              #   CatKeycloakServer (password grant override)
fixtures/                    # Test payloads
  valid/                     #   Signed VPs / SDs for positive tests
  invalid/                   #   Broken payloads for negative tests
tests/                       # Unit tests for shared utilities
archived/                    # Legacy Postman collection (reference only)
environment.py               # Behave hooks (before_all)
```

## Tag Convention

Tests use a dot-separated hierarchical tagging scheme (see [ADR-001](docs/adr/001-behave-tag-naming-convention.md) for full rationale).

### Dimensions

| Prefix | Dimension | Example |
|--------|-----------|---------|
| `@req.` | SRS requirement | `@req.CAT-FR-CO-01` |
| `@gate.` | FACIS I&A acceptance gate | `@gate.GD1`, `@gate.CO1` |
| `@domain.` | API area under test | `@domain.sd`, `@domain.verify` |
| `@cfg.` | Required deployment config | `@cfg.neo4j`, `@cfg.gaiax` |
| _(bare)_ | Test purpose | `@smoke`, `@baseline`, `@regression` |
| _(bare)_ | Dev utility | `@wip`, `@skip`, `@this` |

### Running subsets

```bash
# Smoke tests (default config)
behave --tags="@smoke"

# All baseline (pre-FACIS) behaviour
behave --tags="@baseline"

# Everything for a specific acceptance gate
behave --tags="@gate.CO1"

# Only tests that apply to Fuseki backend
behave --tags="@cfg.fuseki"

# Smoke tests excluding Fuseki-specific and Gaia-X-specific scenarios
behave --tags="@smoke and not @cfg.fuseki and not @cfg.gaiax"
```

### Acceptance Gates

| Tag | Gate | SRS Requirements |
|-----|------|-----------------|
| `@gate.AM1` | Asset Management | CAT-FR-AM-01, -02, -03 |
| `@gate.GD1` | Claim Extraction | CAT-FR-GD-01, -02, -09 |
| `@gate.GD2` | Switchable Graph Backends | CAT-FR-GD-03 thru -08 |
| `@gate.AC1` | Access Control | CAT-FR-AC-01, -02 |
| `@gate.LS1` | Lifecycle and Storage | CAT-FR-LM-01 thru -04, CAT-FR-SF-01 thru -04 |
| `@gate.CO1` | Compliance and Validation | CAT-FR-CO-01 thru -05 |
| `@gate.AU1` | Administration UI | CAT-FR-AU-01 |

### Config variants

The Federated Catalogue is deployed with different configurations (graph backends,
validation policies, trust frameworks). `@cfg.*` tags mark which configuration a
scenario requires, so CI can run exactly the right subset per deployment variant.

| Tag | Config property | Value |
|-----|----------------|-------|
| `@cfg.neo4j` | `graphstore.impl` | `neo4j` |
| `@cfg.fuseki` | `graphstore.impl` | `fuseki` |
| `@cfg.forced-schema-val` | `verification.schema` | `true` |
| `@cfg.no-schema-val` | `verification.schema` | `false` |
| `@cfg.gaiax` | `trust-framework.gaiax.enabled` | `true` |
| `@cfg.no-gaiax` | `trust-framework.gaiax.enabled` | `false` |
| `@cfg.real-sig` | Signature verification | enabled (real DIDs) |
| `@cfg.test-sig` | Signature verification | skipped (test fixtures) |

Scenarios without `@cfg.*` tags are config-agnostic and run in every variant.

## Known Issues

- **`FC_CLIENT_SECRET` in `dev.env`** — The default `dev.env` ships with `FC_CLIENT_SECRET=**********` (placeholder). This must be replaced with the actual Keycloak client secret, otherwise `GET /session`, `GET /participants`, and all user endpoints return 500 (the FC server fails to authenticate to Keycloak admin API).
- **Fixture `@type` namespace** — Valid test fixtures must use `https://w3id.org/gaia-x/core#Participant` (not the legacy `http://w3id.org/gaia-x/participant#Participant`) to match the auto-loaded ontology. See `fixtures/valid/gaiax-participant-correct-type.vp.jsonld`.
- The upstream bdd-executor `KeycloakServer.fetch_token()` hardcodes `client_credentials` grant. This is overridden locally via `CatKeycloakServer`. A PR to make grant type configurable is planned.

## Background

The original implementation of the federated catalogue came with a set of pre-acceptance tests
that can be found at https://gitlab.com/gaia-x/data-infrastructure-federation-services/cat/pre-acceptance-testing/-/blob/main/Test_Stand.postman_collection.json?ref_type=heads.

These were based on a Postman collection that is archived in the `archived/` folder.
There is a newer collection at https://github.com/eclipse-xfsc/federated-catalogue/tree/main/fc-tools, but that one was lacking concrete payloads and assertions.