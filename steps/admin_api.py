"""
Step definitions for Admin API scenarios (CAT-FR-AU-01).

Covers: asset type restriction, schema validation module toggles,
trust framework enabled toggle, and admin stats.
"""
import requests
from behave import given, then, when

from eu.xfsc.bdd.cat.components.fc_server import Server

GAIAX_TRUST_FRAMEWORK_ID = "gaia-x"
SHACL_MODULE_TYPE = "SHACL"


class ContextType:
    fc_server: Server
    requests_response: requests.Response


# ---------------------------------------------------------------------------
# Asset Type Restriction
# ---------------------------------------------------------------------------

@given("asset type restriction is disabled")
def set_asset_type_restriction_disabled(context: ContextType) -> None:
    resp = context.fc_server.set_asset_type_config(enabled=False, allowed_types=[])
    assert resp.status_code == 200, \
        f"Failed to disable asset type restriction: {resp.status_code} {resp.text}"


@given('asset type restriction is enabled with allowed types ""')
def set_asset_type_restriction_enabled_empty(context: ContextType) -> None:
    resp = context.fc_server.set_asset_type_config(enabled=True, allowed_types=[])
    assert resp.status_code == 200, \
        f"Failed to enable asset type restriction: {resp.status_code} {resp.text}"


@given('asset type restriction is enabled with allowed types "{types}"')
def set_asset_type_restriction_enabled(context: ContextType, types: str) -> None:
    allowed = [t.strip() for t in types.split(",") if t.strip()]
    resp = context.fc_server.set_asset_type_config(enabled=True, allowed_types=allowed)
    assert resp.status_code == 200, \
        f"Failed to enable asset type restriction: {resp.status_code} {resp.text}"


@then("asset type restriction is reset to defaults")
def reset_asset_type_restriction(context: ContextType) -> None:
    resp = context.fc_server.set_asset_type_config(enabled=False, allowed_types=[])
    assert resp.status_code == 200, \
        f"Failed to reset asset type restriction: {resp.status_code} {resp.text}"


# ---------------------------------------------------------------------------
# Schema Validation Module Toggle
# ---------------------------------------------------------------------------

@given("SHACL schema module is disabled")
def disable_shacl_module(context: ContextType) -> None:
    resp = context.fc_server.set_schema_module_enabled(SHACL_MODULE_TYPE, enabled=False)
    assert resp.status_code == 200, \
        f"Failed to disable SHACL module: {resp.status_code} {resp.text}"


@given("SHACL schema module is enabled")
def enable_shacl_module(context: ContextType) -> None:
    resp = context.fc_server.set_schema_module_enabled(SHACL_MODULE_TYPE, enabled=True)
    assert resp.status_code == 200, \
        f"Failed to enable SHACL module: {resp.status_code} {resp.text}"


@then("SHACL schema module is re-enabled")
def reenable_shacl_module(context: ContextType) -> None:
    resp = context.fc_server.set_schema_module_enabled(SHACL_MODULE_TYPE, enabled=True)
    assert resp.status_code == 200, \
        f"Failed to re-enable SHACL module: {resp.status_code} {resp.text}"


# ---------------------------------------------------------------------------
# Trust Framework Toggle
# ---------------------------------------------------------------------------

@given("Gaia-X trust framework is disabled")
def disable_gaiax_trust_framework(context: ContextType) -> None:
    resp = context.fc_server.set_trust_framework_enabled(GAIAX_TRUST_FRAMEWORK_ID, enabled=False)
    assert resp.status_code == 200, \
        f"Failed to disable Gaia-X trust framework: {resp.status_code} {resp.text}"


@given("Gaia-X trust framework is enabled")
def enable_gaiax_trust_framework(context: ContextType) -> None:
    resp = context.fc_server.set_trust_framework_enabled(GAIAX_TRUST_FRAMEWORK_ID, enabled=True)
    assert resp.status_code == 200, \
        f"Failed to enable Gaia-X trust framework: {resp.status_code} {resp.text}"


# ---------------------------------------------------------------------------
# Admin Stats
# ---------------------------------------------------------------------------

@when("request admin stats")
def request_admin_stats(context: ContextType) -> None:
    context.requests_response = context.fc_server.get_admin_stats()


@then("response has admin stats fields")
def response_has_admin_stats_fields(context: ContextType) -> None:
    body = context.requests_response.json()
    expected_fields = {
        "totalAssets", "activeAssets", "activeTrustFrameworks",
        "totalUsers", "totalSchemas", "totalParticipants",
        "graphClaimCount", "graphBackend",
    }
    missing = expected_fields - body.keys()
    assert not missing, f"Admin stats response missing fields: {missing}. Got: {list(body.keys())}"
