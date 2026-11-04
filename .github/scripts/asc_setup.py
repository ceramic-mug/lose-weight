#!/usr/bin/env python3
"""One-time Apple setup for TestFlight builds, using an App Store Connect API key.

- Registers the bundle ID (if needed) and turns on HealthKit.
- Finds the Team ID (the bundle ID's seedId) when APPLE_TEAM_ID isn't set.
- Stops with a clear message if the app hasn't been created in App Store Connect yet.

Env: ASC_KEY_ID, ASC_ISSUER_ID, KEY_PATH, BUNDLE_ID, optional APPLE_TEAM_ID, GITHUB_ENV.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"


def fail(msg: str) -> None:
    print(f"::error::{msg}")
    sys.exit(1)


def token() -> str:
    with open(os.environ["KEY_PATH"]) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def api(method: str, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        API + path,
        method=method,
        data=json.dumps(body).encode() if body else None,
        headers={"Authorization": f"Bearer {token()}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        if e.code == 401:
            fail("App Store Connect rejected the API key. Check ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8.")
        if e.code == 403:
            fail("The API key doesn't have permission. Create it with the Admin role.")
        fail(f"App Store Connect API {method} {path} failed ({e.code}): {detail}")
    return {}


def main() -> None:
    bundle_id = os.environ["BUNDLE_ID"]
    q = urllib.parse.urlencode({"filter[identifier]": bundle_id, "limit": 200})
    found = [b for b in api("GET", f"/v1/bundleIds?{q}")["data"] if b["attributes"]["identifier"] == bundle_id]

    if found:
        bid = found[0]
        print(f"Bundle ID {bundle_id} is registered.")
    else:
        bid = api("POST", "/v1/bundleIds", {"data": {"type": "bundleIds", "attributes": {
            "identifier": bundle_id, "name": "Lose Weight", "platform": "IOS"}}})["data"]
        print(f"Registered bundle ID {bundle_id}.")

    caps = api("GET", f"/v1/bundleIds/{bid['id']}/bundleIdCapabilities")["data"]
    if not any(c["attributes"]["capabilityType"] == "HEALTHKIT" for c in caps):
        api("POST", "/v1/bundleIdCapabilities", {"data": {
            "type": "bundleIdCapabilities",
            "attributes": {"capabilityType": "HEALTHKIT"},
            "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bid["id"]}}},
        }})
        print("Turned on HealthKit.")

    team = os.environ.get("APPLE_TEAM_ID") or bid["attributes"].get("seedId")
    if not team:
        fail("Couldn't work out the Team ID. Add an APPLE_TEAM_ID secret.")
    with open(os.environ["GITHUB_ENV"], "a") as f:
        f.write(f"TEAM_ID={team}\n")
    print(f"Team ID: {team}")

    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    if not api("GET", f"/v1/apps?{q}")["data"]:
        fail(f"Almost there: create the app in App Store Connect (Apps › + › New App) with bundle ID "
             f"{bundle_id}, then run this workflow again.")
    print("App record found in App Store Connect.")


if __name__ == "__main__":
    main()
