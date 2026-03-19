#!/usr/bin/env python3
"""
Generate signed JWT VC/VP fixtures for BDD tests.

Produces:
  - A compact JWT suitable for use in BDD fixture files (fixtures/vc20/valid/*.jwt)
  - A JWK public key block ready to paste into docker/did-server/www/.well-known/did.json

Requirements:
  pip install PyJWT[crypto] cryptography

Usage examples:
  # Generate a new Ed25519 key + signed VC JWT
  python3 scripts/generate-jwt-fixture.py vc

  # Generate a signed VP JWT with a specific key file
  python3 scripts/generate-jwt-fixture.py vp --key keys/jwt-signing.pem

  # Specify output path
  python3 scripts/generate-jwt-fixture.py vc --out fixtures/vc20/valid/participant.vc2.signed.jwt

  # VP JWT with intentional iss/holder mismatch (negative test fixture)
  python3 scripts/generate-jwt-fixture.py vp --holder-mismatch --out fixtures/vc20/invalid/vp-iss-holder-mismatch.jwt

DID document update (after generating the key):
  1. Copy the printed "assertionMethod" block into docker/did-server/www/.well-known/did.json
  2. Add the key ID to the "assertionMethod" array in the DID document
  3. Run: docker compose down && docker compose up
     (docker compose restart does NOT flush the FC server's Caffeine DID cache)
"""

import argparse
import base64
import json
import os
import sys
from pathlib import Path

try:
    import jwt as pyjwt
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
    from cryptography.hazmat.primitives.serialization import (
        Encoding, NoEncryption, PrivateFormat, PublicFormat,
    )
except ImportError:
    print("Missing dependencies. Install with:", file=sys.stderr)
    print("  pip install PyJWT[crypto] cryptography", file=sys.stderr)
    sys.exit(1)


ISSUER_DID = "did:web:did-server"
KEY_ID = f"{ISSUER_DID}#jwt-key-1"
FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"


def b64url_no_pad(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def generate_key() -> Ed25519PrivateKey:
    return Ed25519PrivateKey.generate()


def load_key_from_pem(pem_path: str) -> Ed25519PrivateKey:
    from cryptography.hazmat.primitives.serialization import load_pem_private_key
    pem_bytes = Path(pem_path).read_bytes()
    key = load_pem_private_key(pem_bytes, password=None)
    if not isinstance(key, Ed25519PrivateKey):
        print(f"Error: {pem_path} is not an Ed25519 private key", file=sys.stderr)
        sys.exit(1)
    return key


def save_key_pem(key: Ed25519PrivateKey, path: Path) -> None:
    pem = key.private_bytes(Encoding.PEM, PrivateFormat.PKCS8, NoEncryption())
    path.write_bytes(pem)
    print(f"Private key saved: {path}")


def build_public_key_jwk(key: Ed25519PrivateKey, key_id: str) -> dict:
    """Build JWK dict for the public key (to paste into DID document)."""
    pub = key.public_key()
    raw = pub.public_bytes(Encoding.Raw, PublicFormat.Raw)
    return {
        "kty": "OKP",
        "crv": "Ed25519",
        "kid": key_id,
        "x": b64url_no_pad(raw),
        "use": "sig",
    }


def build_vc_jwt_payload(issuer_did: str) -> dict:
    """VC 2.0 JWT: credential properties nested under 'vc' claim.
    Required by the danubetech JwtVerifiableCredentialV2 parser used server-side.
    Uses plain schema.org types (no Gaia-X) to work with gaiaxTrustFrameworkEnabled=false."""
    return {
        "iss": issuer_did,
        "sub": "did:web:participant.example.com",
        "vc": {
            "@context": ["https://www.w3.org/ns/credentials/v2"],
            "type": ["VerifiableCredential"],
            "id": "https://example.com/vc/jwt-bdd-signed-1",
            "issuer": issuer_did,
            "validFrom": "2026-01-01T00:00:00Z",
            "credentialSubject": {
                "id": "did:web:participant.example.com",
                "https://schema.org/name": "Example Corp",
            },
        },
    }


def build_vp_jwt_payload(issuer_did: str, embedded_vc_jwt: str, holder: str | None = None) -> dict:
    """VC 2.0 VP JWT: presentation properties nested under 'vp' claim.
    Required by the danubetech JwtVerifiablePresentationV2 parser used server-side.
    Embeds a signed VC JWT as a compact string in verifiableCredential so the server
    can verify inner VC signatures via JwtSignatureVerifier."""
    if holder is None:
        holder = issuer_did  # iss == holder (happy path)
    return {
        "iss": issuer_did,
        "holder": holder,
        "vp": {
            "@context": ["https://www.w3.org/ns/credentials/v2"],
            "type": ["VerifiablePresentation"],
            "id": "https://example.com/vp/jwt-bdd-signed-1",
            "verifiableCredential": [embedded_vc_jwt],
        },
    }


def sign_jwt(payload: dict, key: Ed25519PrivateKey, kid: str) -> str:
    return pyjwt.encode(
        payload,
        key,
        algorithm="EdDSA",
        headers={"kid": kid, "typ": "JWT"},
    )


def print_did_document_snippet(jwk: dict, key_id: str) -> None:
    print("\n" + "=" * 60)
    print("DID document update (docker/did-server/www/.well-known/did.json):")
    print("=" * 60)
    print('\nAdd to "verificationMethod" array:')
    vm_entry = {
        "id": key_id,
        "type": "JsonWebKey2020",
        "controller": key_id.split("#")[0],
        "publicKeyJwk": jwk,
    }
    print(json.dumps(vm_entry, indent=2))
    print(f'\nAdd to "assertionMethod" array: "{key_id}"')
    print("\nThen: docker compose down && docker compose up")
    print("=" * 60 + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate signed JWT VC/VP test fixtures"
    )
    parser.add_argument("type", choices=["vc", "vp"], help="Fixture type: vc or vp")
    parser.add_argument("--key", help="Path to Ed25519 private key PEM (generates new key if omitted)")
    parser.add_argument("--save-key", help="Save generated key to this PEM path")
    parser.add_argument("--out", help="Output fixture path (prints to stdout if omitted)")
    parser.add_argument(
        "--holder-mismatch",
        action="store_true",
        help="(VP only) Set holder to a different DID than iss — creates negative test fixture",
    )
    parser.add_argument("--issuer", default=ISSUER_DID, help=f"Issuer DID (default: {ISSUER_DID})")
    parser.add_argument("--kid", default=KEY_ID, help=f"Key ID (default: {KEY_ID})")
    args = parser.parse_args()

    # Load or generate key
    if args.key:
        key = load_key_from_pem(args.key)
        print(f"Loaded key: {args.key}")
    else:
        key = generate_key()
        print("Generated new Ed25519 key pair.")
        if args.save_key:
            save_key_pem(key, Path(args.save_key))
        else:
            print("Tip: use --save-key keys/jwt-signing.pem to persist the key")

    jwk = build_public_key_jwk(key, args.kid)

    # Build payload
    if args.type == "vc":
        payload = build_vc_jwt_payload(args.issuer)
    else:
        # VP embeds a signed VC JWT so the server can verify inner VC signatures
        vc_payload = build_vc_jwt_payload(args.issuer)
        embedded_vc_jwt = sign_jwt(vc_payload, key, args.kid)
        holder = "did:web:other-participant.example.com" if args.holder_mismatch else None
        payload = build_vp_jwt_payload(args.issuer, embedded_vc_jwt, holder=holder)
        if args.holder_mismatch:
            print(f"NOTE: holder mismatch fixture — iss={args.issuer}, holder={payload['holder']}")

    # Sign
    compact_jwt = sign_jwt(payload, key, args.kid)

    # Output fixture
    if args.out:
        out_path = Path(args.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(compact_jwt)
        print(f"Fixture written: {out_path}")
    else:
        print("\n--- Compact JWT (paste into fixture file) ---")
        print(compact_jwt)
        print("---\n")

    # Print DID document update instructions
    print_did_document_snippet(jwk, args.kid)

    print("Next steps:")
    print(f"  1. Add the assertionMethod block above to docker/did-server/www/.well-known/did.json")
    print(f"  2. docker compose down && docker compose up")
    print(f"  3. Move the @wip tag from the BDD scenarios to enable them:")
    print(f"     features/08 JWT Signature Verification.feature")


if __name__ == "__main__":
    main()
