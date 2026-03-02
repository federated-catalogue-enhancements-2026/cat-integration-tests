# see https://makefiletutorial.com/

SHELL := /bin/bash -eu -o pipefail

# ---------------------------------------------------------------------------
# Required environment variables for BDD test targets (run_cat_bdd_*).
# Source env.sh before running:  source env.sh
# ---------------------------------------------------------------------------
REQUIRED_BDD_VARS := CAT_FC_HOST CAT_KEYCLOAK_URL CAT_KEYCLOAK_REALM CAT_TEST_USER CAT_TEST_PASSWORD

define check_bdd_env
$(foreach var,$(REQUIRED_BDD_VARS),\
  $(if $($(var)),,$(error $(var) is not set. On local dev stage: run `source env.sh` (see env.sample.sh) or set these manually in your environment.)))
endef

PYTHON_3 ?= python3
PYTHON_D ?= $(HOME)/.python.d
SOURCE_PATHS := "src"

VENV_PATH_DEV := $(PYTHON_D)/dev/eclipse/xfsc/dev-ops/testing/bdd-executor/cat
VENV_PATH_PROD := $(PYTHON_D)/prod/eclipse/xfsc/dev-ops/testing/bdd-executor/cat

# Path to bdd-executor repository root (set via env.sh or override here)
# Default: ../.. (assumes cat-integration-tests is in bdd-executor/implementations/)
EU_XFSC_BDD_CORE_PATH ?= ../..

setup_dev: $(VENV_PATH_DEV)
	mkdir -p .tmp/

$(VENV_PATH_DEV):
	$(PYTHON_3) -m venv $(VENV_PATH_DEV)
	"$(VENV_PATH_DEV)/bin/pip" install -U pip wheel
	cd "$(EU_XFSC_BDD_CORE_PATH)" && "$(VENV_PATH_DEV)/bin/pip" install -e ".[dev]"
	"$(VENV_PATH_DEV)/bin/pip" install -e ".[dev]"
	"$(VENV_PATH_DEV)/bin/pip" freeze > requirements.txt

setup_prod: $(VENV_PATH_PROD)

$(VENV_PATH_PROD):
	$(PYTHON_3) -m venv $(VENV_PATH_PROD)
	"$(VENV_PATH_PROD)/bin/pip" install -U pip wheel
	cd "$(EU_XFSC_BDD_CORE_PATH)" && "$(VENV_PATH_PROD)/bin/pip" install "."
	"$(VENV_PATH_PROD)/bin/pip" install .

isort: setup_dev
	"$(VENV_PATH_DEV)/bin/isort" $(SOURCE_PATHS) tests

pylint: setup_dev
	"$(VENV_PATH_DEV)/bin/pylint" $${ARG_PYLINT_JUNIT:-} $(SOURCE_PATHS) tests

coverage_run: setup_dev
	"$(VENV_PATH_DEV)/bin/coverage" run -m pytest $${ARG_COVERAGE_PYTEST:-} -m "not integration" tests/ src/

coverage_report: setup_dev
	"$(VENV_PATH_DEV)/bin/coverage" report

mypy: setup_dev
	"$(VENV_PATH_DEV)/bin/mypy" $${ARG_MYPY_SOURCE_XML:-} -p eu.xfsc.bdd.cat
	"$(VENV_PATH_DEV)/bin/mypy" $${ARG_MYPY_STEPS_XML:-} steps/ --disable-error-code=misc

code_check: \
	setup_dev \
	isort \
	pylint \
	coverage_run coverage_report \
	mypy

run_cat_bdd_dev: setup_dev
	$(call check_bdd_env)
	source "$(VENV_PATH_DEV)/bin/activate" && \
		"$(VENV_PATH_DEV)/bin/coverage" run --append -m behave $${ARG_BDD_JUNIT:-}

run_cat_bdd_dev_html: setup_dev
	$(call check_bdd_env)
	mkdir -p .tmp/behave
	source "$(VENV_PATH_DEV)/bin/activate" && \
		"$(VENV_PATH_DEV)/bin/coverage" run --append -m behave -f html -o .tmp/behave/behave-report.html

run_cat_bdd_prod: setup_prod
	$(call check_bdd_env)
	source "$(VENV_PATH_PROD)/bin/activate" && behave features/

run_all_test_coverage: coverage_run run_cat_bdd_dev coverage_report

clean_dev:
	rm -rfv "$(VENV_PATH_DEV)"

clean_prod:
	rm -rfv "$(VENV_PATH_PROD)"

activate_env_prod: setup_prod
	@echo "source \"$(VENV_PATH_PROD)/bin/activate\""

activate_env_dev: setup_dev
	@echo "source \"$(VENV_PATH_DEV)/bin/activate\""

licensecheck: setup_dev
	"$(VENV_PATH_DEV)/bin/pip" freeze > ".tmp/requirements.txt"
	cd .tmp/ && "$(VENV_PATH_DEV)/bin/licensecheck" -u requirements > THIRD-PARTY.txt

# --- Fixture Signing (dev-only, rare) ---
# Signs every *.jsonld in fixtures/unsigned/ → fixtures/valid/<name>.signed.jsonld
# Signed fixtures are committed — re-sign only when unsigned content changes.
# Requires: Java 21+, FC_SIGNER_JAR and FC_SIGNER_KEY env vars.
# Build the signer:
#   cd <federated-catalogue> && mvn package -pl fc-tools/signer -am -DskipTests
#   # Produces: fc-tools/signer/target/fc-tools-signer-2.1.0-SNAPSHOT-full.jar
#
# Usage:
#   FC_SIGNER_JAR=/path/to/fc-tools-signer-2.1.0-SNAPSHOT-full.jar \
#   FC_SIGNER_KEY=/path/to/rsa2048.sign.pem \
#     make sign-fixtures

UNSIGNED_DIR := fixtures/unsigned
SIGNED_DIR := fixtures/valid

# did:jwk DID — embeds the public key + x5u cert chain URL in the DID itself.
# Resolved via Universal Resolver (requires uni-resolver-client >= 0.51.0).
# x5u points to did-server cert chain for trust anchor validation.
# Regenerate with: python3 scripts/generate-did-jwk.py <pub-key.pem> <x5u-url>
# Inspect with:    python3 scripts/decode-did-jwk.py <did:jwk:...>
FC_SIGNER_DID := did:jwk:eyJhbGciOiJQUzI1NiIsImUiOiJBUUFCIiwia3R5IjoiUlNBIiwibiI6ImtfR3pvRnFPNHgzNjJleVowZnhqRDR1SlhZX2xacEZla1lWUEJCNjVQVWZJMHRSYWtfc3p1WlVVY3hEM3Y5eW00SzFtX0l5QWFtUVlhbHBiYVdMYnRELWItaU43TmcycExlZWs2Qkg5Q21WV2trN1RCTDFQYkROX0p3VnRkREpwcTJ3bmpLM1ItMjRfVWwzcGJXS2oxWk5wbHRVNjlJbGZ4YXhMMjJGMU1KeTVpRy1Ibkl0NGNMNS02UTJ4TjRJWmRHWjIySFN3dURsSm1PNW9qdG5RQTBlbDRuTURDc3V3Um52Y2FUbkdHbUxnYUc5R0RSWmR6Z1RsazBrbkktbFNWSFVsZWJiZXNhbFJ6ZHo5d3JkdFR0bmFWQWs0dDRJZ19pZUpJLTdVVjh6Z2ltNEpsNlAzLWY2bFhxdFFOd3pEMGk5VExLM25NMGtsMGdXUHk2eXVVUSIsInVzZSI6InNpZyIsIng1dSI6Imh0dHBzOi8vZGlkLXNlcnZlci9jZXJ0cy9jaGFpbi5wZW0ifQ\#0

sign-fixtures:
ifndef FC_SIGNER_JAR
	$(error FC_SIGNER_JAR is not set. Point it to the fc-tools-signer fat jar.)
endif
ifndef FC_SIGNER_KEY
	$(error FC_SIGNER_KEY is not set. Point it to rsa2048.sign.pem from fc-tools/signer.)
endif
	@unsigned=$$(find $(UNSIGNED_DIR) -name '*.jsonld' 2>/dev/null); \
	if [ -z "$$unsigned" ]; then \
		echo "No .jsonld files found in $(UNSIGNED_DIR)/"; exit 1; \
	fi; \
	for src in $$unsigned; do \
		base=$$(basename "$$src" .jsonld); \
		dest="$(SIGNED_DIR)/$${base}.signed.jsonld"; \
		echo "Signing $$src → $$dest"; \
		java -jar "$(FC_SIGNER_JAR)" \
			sd="$$(pwd)/$$src" \
			ssd="$$(pwd)/$$dest" \
			prk="$(FC_SIGNER_KEY)" \
			m="$(FC_SIGNER_DID)" || exit 1; \
	done; \
	echo "Done. Signed $$(echo "$$unsigned" | wc -w | tr -d ' ') fixture(s) into $(SIGNED_DIR)/"
