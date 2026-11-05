#!/usr/bin/env python3
"""Temporary App Store signing for one CI run, using the App Store Connect API key.

  signing.py create [ios|mac] → makes the certificates + App Store profile, installs them,
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


def new_certificate(cert_type: str) -> tuple[str, bytes]:
    """Create a certificate of `cert_type`; returns (id, PKCS#12 bytes with its private key)."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, f"Sensible CI {RUN}")]))
           .sign(key, hashes.SHA256()))
    cert = api("POST", "/v1/certificates", {"data": {"type": "certificates", "attributes": {
        "certificateType": cert_type,
        "csrContent": csr.public_bytes(serialization.Encoding.PEM).decode()}}})["data"]
    der = base64.b64decode(cert["attributes"]["certificateContent"])
    p12 = pkcs12.serialize_key_and_certificates(
        b"ci", key, x509.load_der_x509_certificate(der), None,
        serialization.BestAvailableEncryption(KEYCHAIN_PW.encode()))
    print(f"Created temporary {cert_type} certificate {cert['id']}.")
    return cert["id"], p12


def create(platform: str) -> None:
    bundle_id = os.environ["BUNDLE_ID"]
    mac = platform == "mac"

    # 1. Certificates: Apple Distribution, plus the installer certificate the Mac .pkg needs.
    types = ["DISTRIBUTION"] + (["MAC_INSTALLER_DISTRIBUTION"] if mac else [])
    certs = []
    cert_ids: list[str] = []
    for t in types:
        cid, p12 = new_certificate(t)
        cert_ids.append(cid)
        env_out(CI_CERT_IDS=",".join(cert_ids))  # saved as we go so cleanup always sees them
        certs.append(p12)

    # 2. App Store provisioning profile for the bundle ID (signed with the distribution cert).
    found = api("GET", f"/v1/bundleIds?filter[identifier]={bundle_id}")["data"]
    bid = next(b for b in found if b["attributes"]["identifier"] == bundle_id)
    name = f"Sensible CI {RUN} {platform}"
    profile = api("POST", "/v1/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": name, "profileType": "MAC_APP_STORE" if mac else "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bid["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": cert_ids[0]}]},
        },
    }})["data"]
    env_out(CI_PROFILE_ID=profile["id"], CI_PROFILE_NAME=name)
    content = base64.b64decode(profile["attributes"]["profileContent"])
    uuid = profile["attributes"]["uuid"]
    ext = "provisionprofile" if mac else "mobileprovision"
    # Older and newer Xcode versions look in different places; install to both.
    for d in [Path.home() / "Library/MobileDevice/Provisioning Profiles",
              Path.home() / "Library/Developer/Xcode/UserData/Provisioning Profiles"]:
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{uuid}.{ext}").write_bytes(content)
    print(f"Created and installed profile '{name}'.")

    # 3. Put the identities in a throwaway keychain codesign can use.
    sh("security", "create-keychain", "-p", KEYCHAIN_PW, str(KEYCHAIN))
    sh("security", "set-keychain-settings", "-lut", "21600", str(KEYCHAIN))
    sh("security", "unlock-keychain", "-p", KEYCHAIN_PW, str(KEYCHAIN))
    for i, data in enumerate(certs):
        p12 = TMP / f"signing-{i}.p12"
        p12.write_bytes(data)
        sh("security", "import", str(p12), "-k", str(KEYCHAIN), "-P", KEYCHAIN_PW, "-A",
           "-t", "cert", "-f", "pkcs12")
        p12.unlink()
    sh("security", "set-key-partition-list", "-S", "apple-tool:,apple:,codesign:,productbuild:", "-s",
       "-k", KEYCHAIN_PW, str(KEYCHAIN))
    existing = subprocess.run(["security", "list-keychains", "-d", "user"], capture_output=True, text=True).stdout
    keychains = [k.strip().strip('"') for k in existing.split()]
    sh("security", "list-keychains", "-d", "user", "-s", str(KEYCHAIN), *keychains)

    # 4. Export options for manual signing with this profile.
    options = {
        "method": "app-store-connect",
        "destination": "upload",
        "teamID": os.environ["TEAM_ID"],
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {bundle_id: name},
        # App Store / TestFlight exports only allow Production.
        "iCloudContainerEnvironment": "Production",
    }
    if mac:
        options["installerSigningCertificate"] = "3rd Party Mac Developer Installer"
    with open(TMP / "ExportOptions.plist", "wb") as f:
        plistlib.dump(options, f)
    print("Signing ready.")


def cleanup() -> None:
    cert_ids = [c for c in os.environ.get("CI_CERT_IDS", os.environ.get("CI_CERT_ID", "")).split(",") if c]
    profile_id = os.environ.get("CI_PROFILE_ID")
    if profile_id:
        try:
            api("DELETE", f"/v1/profiles/{profile_id}")
            print("Deleted temporary profile.")
        except SystemExit:
            pass
    for cert_id in cert_ids:
        try:
            api("DELETE", f"/v1/certificates/{cert_id}")
            print(f"Revoked temporary certificate {cert_id}.")
        except SystemExit:
            pass
    subprocess.run(["security", "delete-keychain", str(KEYCHAIN)])


if __name__ == "__main__":
    if sys.argv[1] == "create":
        create(sys.argv[2] if len(sys.argv) > 2 else "ios")
    else:
        cleanup()
