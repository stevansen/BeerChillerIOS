#!/usr/bin/env python3
"""Minimal App Store Connect API client.

There are no third-party packages on this machine, so the ES256 JWT is signed by
shelling out to `openssl` and the DER signature is converted to the raw r||s form
JWS requires. Everything else is urllib.

Credentials come from the environment, never from this file. The key ID and
issuer ID are identifiers rather than secrets, but this repository is public and
there is no reason to publish them; the actual secret is the .p8 private key,
which is read from ~/.appstoreconnect/private_keys/ and never printed or copied.

    export ASC_KEY_ID=ABCDE12345
    export ASC_ISSUER_ID=00000000-0000-0000-0000-000000000000
    python3 tools/asc.py          # lists the account's apps: an auth smoke test
"""
import base64
import json
import os
import ssl
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

KEY_ID = os.environ.get("ASC_KEY_ID", "")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
BASE = "https://api.appstoreconnect.apple.com/v1"

# The App Store Connect id for com.bierchiller.app. Not a secret — it is in
# every App Store URL for the app — and overridable for a different account.
APP_ID = os.environ.get("ASC_APP_ID", "6798018586")

_context = ssl.create_default_context()


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode().rstrip("=")


def _der_to_raw(der: bytes) -> bytes:
    """ECDSA DER SEQUENCE{r,s} -> the fixed-width r||s that JWS ES256 wants."""
    assert der[0] == 0x30
    index = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        assert der[index] == 0x02
        length = der[index + 1]
        value = der[index + 2: index + 2 + length].lstrip(b"\x00").rjust(32, b"\x00")
        out += value
        index += 2 + length
    return out


def token() -> str:
    if not KEY_ID or not ISSUER_ID:
        raise SystemExit(
            "set ASC_KEY_ID and ASC_ISSUER_ID — both are shown in App Store "
            "Connect under Users and Access -> Integrations -> App Store Connect API")
    if not os.path.isfile(KEY_PATH):
        raise SystemExit(
            f"private key not found: {KEY_PATH}\n"
            "App Store Connect lets you download the .p8 once, when the key is "
            "created. If it is lost, create a new key under Users and Access -> "
            "Integrations -> App Store Connect API.")
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 15 * 60,
               "aud": "appstoreconnect-v1"}
    signing_input = (f"{_b64url(json.dumps(header).encode())}."
                     f"{_b64url(json.dumps(payload).encode())}")
    der = subprocess.run(["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
                         input=signing_input.encode(),
                         capture_output=True, check=True).stdout
    return f"{signing_input}.{_b64url(_der_to_raw(der))}"


def request(method, path, body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, context=_context, timeout=120) as response:
            text = response.read().decode()
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as error:
        raise SystemExit(f"{method} {url} -> {error.code}\n{error.read().decode()}")


def get(path, **params):
    if params:
        path += ("&" if "?" in path else "?") + urllib.parse.urlencode(params)
    return request("GET", path)


def try_get(path, **params):
    """Like `get`, but returns None instead of exiting — for probing endpoints
    whose availability differs between API versions."""
    try:
        return get(path, **params)
    except SystemExit:
        return None


if __name__ == "__main__":
    for app in get("/apps", **{"limit": 20}).get("data", []):
        a = app["attributes"]
        print(f"{app['id']}  {a.get('bundleId')}  {a.get('name')}  "
              f"primary={a.get('primaryLocale')}")
