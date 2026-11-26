#!/usr/bin/env python3
"""
Print release-note lines for an Elastic CI Stack release's Amazon Linux 2023
AMIs: the kernel each booted, links to the files its release build published
next to the CloudFormation template, and the CVEs those files list that the
previous release's files did not (see .buildkite/steps/save-security-fixes.sh).

A CVE is "newly listed" when the previous release's files did not have it. That
includes CVEs Amazon Linux published after the previous release was tested, so
it does not mean this release introduced the fix.

Fails until the release build has published the files for both architectures.
Prints nothing when no CVE is newly listed. Leaves the CVE list out when the
previous release has no files.

Usage: ami_security_notes.py [--base-url URL] PREVIOUS_TAG RELEASE_TAG
"""

import argparse
import re
import sys
import urllib.error
import urllib.request
from typing import Optional, Set

DEFAULT_BASE_URL = "https://s3.amazonaws.com/buildkite-aws-stack"
CVE_URL = "https://explore.alas.aws.amazon.com/{}.html"
# Stack architecture name, as used in file names and release notes.
ARCHITECTURES = {"amd64": "AMD64", "arm64": "ARM64"}


def fetch(url: str) -> Optional[str]:
    """Return the text at url, or None when it does not exist."""
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            return response.read().decode()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    except urllib.error.URLError as error:
        if isinstance(error.reason, FileNotFoundError):
            return None
        raise


def cves(text: str) -> Set[str]:
    """The CVEs in "cve CVE-2026-98432 ALAS2023-2026-3335" lines."""
    return {line.split()[1] for line in text.splitlines() if line.startswith("cve ")}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("previous_tag")
    parser.add_argument("release_tag")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="where releases publish their security fixes")
    args = parser.parse_args()

    def url(tag: str, arch: str) -> str:
        return f"{args.base_url}/{tag}/security-fixes-linux-{arch}.txt"

    release = {arch: fetch(url(args.release_tag, arch)) or "" for arch in ARCHITECTURES}
    kernels = {}
    for arch, text in release.items():
        # kernel 6.12.115-140.210.amzn2023.x86_64
        found = [line.split()[1] for line in text.splitlines() if line.startswith("kernel ")]
        if not found:
            print(f"{args.release_tag} has not published its security fixes for {arch}.", file=sys.stderr)
            return 1
        kernels[arch] = found[0]

    previous = [fetch(url(args.previous_tag, arch)) for arch in ARCHITECTURES]
    new: Set[str] = set()
    if all(previous):
        new = set().union(*map(cves, release.values())) - set().union(*map(cves, previous))
        if not new:
            print(f"No newly listed CVEs since {args.previous_tag}; leaving out the Security line.", file=sys.stderr)
            return 0
    else:
        print(f"{args.previous_tag} has no security fixes to compare with; leaving out the CVE list.", file=sys.stderr)

    booted = "; ".join(f"{label} `{kernels[arch]}`" for arch, label in ARCHITECTURES.items())
    files = ", ".join(f"[{label}]({url(args.release_tag, arch)})" for arch, label in ARCHITECTURES.items())
    print(f"- Amazon Linux 2023 booted kernels: {booted}. Packages and fixed CVEs: {files}.")
    if new:
        # CVE-2026-9999 sorts before CVE-2026-10000.
        listed = sorted(new, key=lambda cve: [int(n) for n in re.findall(r"\d+", cve)])
        print(f"  <details><summary>{len(new)} CVEs newly listed since {args.previous_tag}</summary>\n")
        print("\n".join(f"  - [{cve}]({CVE_URL.format(cve)})" for cve in listed))
        print("\n  </details>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
