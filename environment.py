# noinspection PyUnresolvedReferences
from eu.xfsc.bdd.core import environment
# noinspection PyUnresolvedReferences
from eu.xfsc.bdd.core.steps import *
from eu.xfsc.bdd.core.server.keycloak import Token
from pathlib import Path


def before_all(context) -> None:
    environment.before_all(context)

    context.FileToken = Token(Path(__file__).parent / ".tmp")
