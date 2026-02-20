from pathlib import Path

import requests
from behave import given, when, then

from eu.xfsc.bdd.core.server.keycloak import KeycloakServer, Token

from eu.xfsc.bdd.cat.components.fc_server import Server

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


class ContextType:
    fc_server: Server
    keycloak: KeycloakServer
    requests_response: requests.Response
    FileToken: Token


@given("Federated Catalogue Server is up")
def check_fc_server_up(context: ContextType) -> None:
    context.fc_server = Server(keycloak=context.keycloak)
    assert context.fc_server.is_up(), f"FC Server is not up at {context.fc_server.host}"


# -- Self-Descriptions --

@when("request list of self-descriptions")
def request_list_self_descriptions(context: ContextType) -> None:
    context.requests_response = context.fc_server.get_self_descriptions()


@when('add self-description')
def add_self_description(context: ContextType) -> None:
    assert context.text, "Step requires docstring with SD payload"
    context.requests_response = context.fc_server.add_self_description(context.text)


@when('delete self-description "{sd_hash}"')
def delete_self_description(context: ContextType, sd_hash: str) -> None:
    context.requests_response = context.fc_server.delete_self_description(sd_hash)


@when('revoke self-description "{sd_hash}"')
def revoke_self_description(context: ContextType, sd_hash: str) -> None:
    context.requests_response = context.fc_server.revoke_self_description(sd_hash)


# -- Verification --

@when("verify self-description")
def verify_self_description(context: ContextType) -> None:
    assert context.text, "Step requires docstring with SD payload"
    context.requests_response = context.fc_server.verify(context.text)


@when('verify self-description from fixture "{fixture_path}"')
def verify_self_description_from_fixture(context: ContextType, fixture_path: str) -> None:
    payload = (FIXTURES_DIR / fixture_path).read_text()
    context.requests_response = context.fc_server.verify(payload)


@when('verify self-description from fixture "{fixture_path}" skipping signatures')
def verify_sd_from_fixture_skip_sigs(context: ContextType, fixture_path: str) -> None:
    payload = (FIXTURES_DIR / fixture_path).read_text()
    context.requests_response = context.fc_server.verify(payload, params={
        "verifyVPSignature": "false",
        "verifyVCSignature": "false",
    })


# -- Query --

@when('execute query "{statement}"')
def execute_query(context: ContextType, statement: str) -> None:
    context.requests_response = context.fc_server.query(statement)


# -- Schemas --

@when("request list of schemas")
def request_list_schemas(context: ContextType) -> None:
    context.requests_response = context.fc_server.get_schemas()


# -- Participants --

@when("request list of participants")
def request_list_participants(context: ContextType) -> None:
    context.requests_response = context.fc_server.get_participants()


# -- Session --

@when("request current session")
def request_current_session(context: ContextType) -> None:
    context.requests_response = context.fc_server.get_session()
