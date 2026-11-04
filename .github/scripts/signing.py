#!/usr/bin/env python3
"""Temporary App Store signing for one CI run, using the App Store Connect API key.

  signing.py create   → makes a distribution certificate + App Store profile, installs both,
                         and writes their IDs to $GITHUB_ENV
  signing.py cleanup  → revokes that certificate and deletes the profile

Nothing is kept between runs, so no signing secrets need to be stored. Revoking a
distribution certificate does not affect builds already uploaded to TestFlight.
"""
import base64
import os
import plistlib
import subprocess
import sys
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
from cryptography.x509.oid import NameOID

sys.path.insert(0, str(Path(__file__).parent))
from asc_setup import api, fail  # noqa: E402

TMP = Path(os.environ.get("RUNNER_TEMP", "/tmp"))
KEYCHAIN = TMP / "signing.keychain-db"
KEYCHAIN_PW = "ci-temporary"
RUN = os.environ.get("GITHUB_RUN_ID", "local")


def sh(*args: str) -> None:
    subprocess.run(args, check=True)


def env_out(**kv: str) -> None:
    with open(os.environ["GITHUB_ENV"], "a") as f:
        for k, v in kv.items():
            f.write(f"{k}={v}\n")


def create() -> None:
    bundle_id = os.environ["BUNDLE_ID"]

    # 1. Key pair + certificate signing request.
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, f"Sensible CI {RUN}")]))
           .sign(key, hashes.SHA256()))
    csr_pem = csr.public_bytes(serialization.Encoding.PEM).decode()

    # 2. Distribution certificate.
    cert = api("POST", "/v1/certificates", {"data": {"type": "certificates", "attributes": {
        "certificateType": "DISTRIBUTION", "csrContent": csr_pem}}})["data"]
    env_out(CI_CERT_ID=cert["id"])
    der = base64.b64decode(cert["attributes"]["certificateContent"])
    print(f"Created temporary distribution certificate {cert['id']}.")

    # 3. App Store provisioning profile for the bundle ID.
    found = api("GET", f"/v1/bundleIds?filter[identifier]={bundle_id}")["data"]
    bid = next(b for b in found if b["attributes"]["identifier"] == bundle_id)
    name = f"Sensible CI {RUN}"
    profile = api("POST", "/v1/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bid["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": cert["id"]}]},
        },
    }})["data"]
    env_out(CI_PROFILE_ID=profile["id"], CI_PROFILE_NAME=name)
    content = base64.b64decode(profile["attributes"]["profileContent"])
    uuid = profile["attributes"]["uuid"]
    profiles_dir = Path.home() / "Library/MobileDevice/Provisioning Profiles"
    profiles_dir.mkdir(parents=True, exist_ok=True)
    (profiles_dir / f"{uuid}.mobileprovision").write_bytes(content)
    print(f"Created and installed profile '{name}'.")

    # 4. Put the identity in a throwaway keychain codesign can use.
    p12 = TMP / "signing.p12"
    p12.write_bytes(pkcs12.serialize_key_and_certificates(
        b"ci", key, x509.load_der_x509_certificate(der), None,
        serialization.BestAvailableEncryption(KEYCHAIN_PW.encode())))
    sh("security", "create-keychain", "-p", KEYCHAIN_PW, str(KEYCHAIN))
    sh("security", "set-keychain-settings", "-lut", "21600", str(KEYCHAIN))
    sh("security", "unlock-keychain", "-p", KEYCHAIN_PW, str(KEYCHAIN))
    sh("security", "import", str(p12), "-k", str(KEYCHAIN), "-P", KEYCHAIN_PW, "-A",
       "-t", "cert", "-f", "pkcs12")
    sh("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:", "-s",
       "-k", KEYCHAIN_PW, str(KEYCHAIN))
    existing = subprocess.run(["security", "list-keychains", "-d", "user"], capture_output=True, text=True).stdout
    keychains = [k.strip().strip('"') for k in existing.split()]
    sh("security", "list-keychains", "-d", "user", "-s", str(KEYCHAIN), *keychains)
    p12.unlink()

    # 5. Export options for manual signing with this profile.
    with open(TMP / "ExportOptions.plist", "wb") as f:
        plistlib.dump({
            "method": "app-store-connect",
            "destination": "upload",
            "teamID": os.environ["TEAM_ID"],
            "signingStyle": "manual",
            "signingCertificate": "Apple Distribution",
            "provisioningProfiles": {bundle_id: name},
        }, f)
    print("Signing ready.")


def cleanup() -> None:
    cert_id = os.environ.get("CI_CERT_ID")
    profile_id = os.environ.get("CI_PROFILE_ID")
    if profile_id:
        try:
            api("DELETE", f"/v1/profiles/{profile_id}")
            print("Deleted temporary profile.")
        except SystemExit:
            pass
    if cert_id:
        try:
            api("DELETE", f"/v1/certificates/{cert_id}")
            print("Revoked temporary certificate.")
        except SystemExit:
            pass
    subprocess.run(["security", "delete-keychain", str(KEYCHAIN)])


if __name__ == "__main__":
    {"create": create, "cleanup": cleanup}[sys.argv[1]]()
