"""
Federated Catalogue Server BDD Wrapper
"""
from typing import Any, Optional

import pydantic
import requests

from eu.xfsc.bdd.core.defaults import CONNECT_TIMEOUT_IN_SECONDS
from eu.xfsc.bdd.core.server.keycloak import BaseServiceKeycloak
from eu.xfsc.bdd.cat.env import FC_HOST


class Server(BaseServiceKeycloak):
    """
    Federated Catalogue REST API

    See OpenAPI spec: federated-catalogue/openapi/fc_openapi.yaml
    """
    host: pydantic.HttpUrl = pydantic.HttpUrl(FC_HOST or "http://localhost:8081")

    @property
    def health_url(self) -> str:
        return f"{self.host}actuator/health"

    def is_up(self) -> bool:
        try:
            response = requests.get(
                self.health_url,
                timeout=CONNECT_TIMEOUT_IN_SECONDS
            )
            return response.status_code == 200
        except requests.exceptions.ConnectionError:
            return False

    # -- Self-Descriptions --

    def add_self_description(self, payload: str) -> requests.Response:
        """POST /self-descriptions"""
        self._update_header(content_type="application/json")
        return self.http.post(
            url=f"{self.host}self-descriptions",
            data=payload,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def get_self_descriptions(self, params: Optional[dict[str, Any]] = None) -> requests.Response:
        """GET /self-descriptions"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}self-descriptions",
            params=params,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def get_self_description(self, sd_hash: str) -> requests.Response:
        """GET /self-descriptions/{hash}"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}self-descriptions/{sd_hash}",
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def delete_self_description(self, sd_hash: str) -> requests.Response:
        """DELETE /self-descriptions/{hash}"""
        self._update_header()
        return self.http.delete(
            url=f"{self.host}self-descriptions/{sd_hash}",
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def revoke_self_description(self, sd_hash: str) -> requests.Response:
        """POST /self-descriptions/{hash}/revoke"""
        self._update_header()
        return self.http.post(
            url=f"{self.host}self-descriptions/{sd_hash}/revoke",
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    # -- Verification --

    def verify(self, payload: str) -> requests.Response:
        """POST /verification"""
        self._update_header(content_type="application/json")
        return self.http.post(
            url=f"{self.host}verification",
            data=payload,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    # -- Query --

    def query(self, statement: str, params: Optional[dict[str, Any]] = None) -> requests.Response:
        """POST /query"""
        self._update_header(content_type="application/json")
        body: dict[str, Any] = {"statement": statement}
        if params:
            body["parameters"] = params
        return self.http.post(
            url=f"{self.host}query",
            json=body,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    # -- Schemas --

    def get_schemas(self, params: Optional[dict[str, Any]] = None) -> requests.Response:
        """GET /schemas"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}schemas",
            params=params,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def add_schema(self, payload: str) -> requests.Response:
        """POST /schemas"""
        self._update_header(content_type="application/json")
        return self.http.post(
            url=f"{self.host}schemas",
            data=payload,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    # -- Participants --

    def get_participants(self, params: Optional[dict[str, Any]] = None) -> requests.Response:
        """GET /participants"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}participants",
            params=params,
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    def get_participant(self, participant_id: str) -> requests.Response:
        """GET /participants/{participantId}"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}participants/{participant_id}",
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )

    # -- Session --

    def get_session(self) -> requests.Response:
        """GET /session"""
        self._update_header()
        return self.http.get(
            url=f"{self.host}session",
            timeout=CONNECT_TIMEOUT_IN_SECONDS
        )
