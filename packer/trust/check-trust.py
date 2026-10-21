#!/usr/bin/env python3
"""Offline eMudhra regression check; optionally sanitize a bundled PEM store."""
import argparse
import hashlib
from pathlib import Path
import re
import ssl
import tempfile

BLOCKED = {
    "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4",
    "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
    "7dd78d5f4f13459a83dff9abbba62edbaf6f2d102bf257fd712f4d9f2746ed8d",
    "f2edaaff3d9b701fb4d14c9f285f8c0bad90fc3bcc1fa07d47f4718edaba34a5",
}
PEM = re.compile(r"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", re.S)


def fingerprint(pem):
    return hashlib.sha256(ssl.PEM_cert_to_DER_cert(pem)).hexdigest()


def check(bundle):
    certs = PEM.findall(bundle.read_text())
    assert certs, f"Empty CA bundle: {bundle}"
    assert not (set(map(fingerprint, certs)) & BLOCKED), f"Affected root in {bundle}"
    print(f"PASS: {bundle}: nonempty bundle, affected roots absent")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sanitize", action="store_true")
    parser.add_argument("bundles", nargs="*", type=Path)
    args = parser.parse_args()
    bundles = args.bundles or [Path(ssl.get_default_verify_paths().cafile)]
    for bundle in bundles:
        if args.sanitize:
            certs = PEM.findall(bundle.read_text())
            assert certs, f"Empty CA bundle: {bundle}"
            filtered = "\n".join(c for c in certs if fingerprint(c) not in BLOCKED) + "\n"
            # Validate before overwriting; an interrupted build must not publish.
            with tempfile.NamedTemporaryFile(mode="w", suffix=".pem") as tmp:
                tmp.write(filtered)
                tmp.flush()
                check(Path(tmp.name))
            bundle.write_text(filtered)
        check(bundle)


if __name__ == "__main__":
    main()
