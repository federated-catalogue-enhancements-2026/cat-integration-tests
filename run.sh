#!/usr/bin/env bash
set -eu -o pipefail

VENV="$HOME/.python.d/dev/eclipse/xfsc/dev-ops/testing/bdd-executor/cat"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSCALER_CERT="$SCRIPT_DIR/../federated-catalogue/docker/certs/ZscalerRootCertificate.crt"

# Trust Zscaler cert for pip/requests (corporate proxy)
if [ -f "$ZSCALER_CERT" ]; then
    export SSL_CERT_FILE="$ZSCALER_CERT"
    export REQUESTS_CA_BUNDLE="$ZSCALER_CERT"
fi

# Windows venvs use Scripts/, Linux/Mac use bin/
if [ -d "$VENV/Scripts" ]; then
    VENV_BIN="$VENV/Scripts"
else
    VENV_BIN="$VENV/bin"
fi

setup() {
    if [ ! -f "$VENV/Scripts/pip" ] && [ ! -f "$VENV/bin/pip" ]; then
        echo "==> Creating virtual environment..."
        rm -rf "$VENV"
        python -m venv "$VENV"
        # Re-detect after creation
        if [ -d "$VENV/Scripts" ]; then VENV_BIN="$VENV/Scripts"; else VENV_BIN="$VENV/bin"; fi
        "$VENV_BIN/python" -m pip install -U pip wheel
        echo "==> Installing bdd-executor framework from $EU_XFSC_BDD_CORE_PATH..."
        (cd "$EU_XFSC_BDD_CORE_PATH" && "$VENV_BIN/pip" install -e ".[dev]")
        echo "==> Installing cat-integration-tests package..."
        (cd "$SCRIPT_DIR" && "$VENV_BIN/pip" install -e ".[dev]")
        mkdir -p "$SCRIPT_DIR/.tmp"
        echo "==> Setup done."
    else
        echo "==> Venv already exists, skipping setup."
    fi
}

run() {
    setup
    echo "==> Running BDD tests..."
    source "$VENV_BIN/activate"
    coverage run --append -m behave "$@"
}

run_html() {
    setup
    mkdir -p "$SCRIPT_DIR/.tmp/behave"
    echo "==> Running BDD tests (HTML report)..."
    source "$VENV_BIN/activate"
    coverage run --append -m behave -f html -o "$SCRIPT_DIR/.tmp/behave/behave-report.html" "$@"
    echo "==> Report: $SCRIPT_DIR/.tmp/behave/behave-report.html"
}

case "${1:-}" in
    setup)      setup ;;
    run)        shift; run "$@" ;;
    run_html)   shift; run_html "$@" ;;
    *)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  setup       Create venv and install dependencies"
        echo "  run         Run all BDD tests"
        echo "  run_html    Run BDD tests and generate HTML report"
        echo ""
        echo "Examples:"
        echo "  $0 run"
        echo "  $0 run --tags=@smoke"
        echo "  $0 run_html"
        echo ""
        echo "Troubleshooting (Windows):"
        echo "  If setup fails mid-way, the venv may be left in a broken state."
        echo "  Reset it with: rm -rf \"$VENV\""
        ;;
esac
