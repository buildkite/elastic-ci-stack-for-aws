#!/usr/bin/env python3
"""
Print release-note lines for the security fixes an Elastic CI Stack release
picked up through its Amazon Linux 2023 AMIs.

Each release build publishes the packages installed in its AMIs next to the
CloudFormation template (see .buildkite/steps/save-package-list.sh). This script
compares the lists of two releases. For every package that moved from version A
to version B, it prints the Amazon Linux advisories whose fixed version F
satisfies A < F <= B, with their CVEs.

It prints nothing when no package crossed a fix, and when either release has no
package list, so a release that reuses the previous AMI packages gets no lines.
A release's list exists only once its tag build has published, so run this
after that build passes.

Usage: ami_security_notes.py PREVIOUS_TAG RELEASE_TAG
"""

import argparse
import collections
import functools
import gzip
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from typing import Dict, Iterable, List, Optional, Tuple

DEFAULT_BASE_URL = "https://s3.amazonaws.com/buildkite-aws-stack"
# Amazon Linux serves its repository from a per-release directory; "latest"
# always has every advisory published so far.
AL2023_MIRROR_LIST = "https://cdn.amazonlinux.com/al2023/core/mirrors/latest/x86_64/mirror.list"
ADVISORY_URL = "https://alas.aws.amazon.com/AL2023/{}.html"

# Stack architecture name, as used in file names and release notes.
ARCHITECTURES = {"amd64": "AMD64", "arm64": "ARM64"}
SEVERITIES = ["Critical", "Important", "Medium", "Low"]
# More CVEs than this go in a collapsed list under the line.
INLINE_CVE_LIMIT = 4

Evr = Tuple[int, str, str]  # epoch, version, release
PackageKey = Tuple[str, str]  # name, RPM architecture


def rpmvercmp(a: str, b: str) -> int:
    """Compare two RPM version or release strings the way rpm does."""
    i = j = 0
    while i < len(a) or j < len(b):
        while i < len(a) and not (a[i].isalnum() or a[i] in "~^"):
            i += 1
        while j < len(b) and not (b[j].isalnum() or b[j] in "~^"):
            j += 1
        a_tilde = i < len(a) and a[i] == "~"
        b_tilde = j < len(b) and b[j] == "~"
        if a_tilde or b_tilde:
            # A tilde sorts before everything, even the end of the string.
            if not a_tilde:
                return 1
            if not b_tilde:
                return -1
            i, j = i + 1, j + 1
            continue
        a_caret = i < len(a) and a[i] == "^"
        b_caret = j < len(b) and b[j] == "^"
        if a_caret or b_caret:
            # A caret sorts after the end of the string, but before any other text.
            if i >= len(a):
                return -1
            if j >= len(b):
                return 1
            if not a_caret:
                return 1
            if not b_caret:
                return -1
            i, j = i + 1, j + 1
            continue
        if i >= len(a) or j >= len(b):
            break
        numeric = a[i].isdigit()
        in_segment = str.isdigit if numeric else str.isalpha
        a_start, b_start = i, j
        while i < len(a) and in_segment(a[i]):
            i += 1
        while j < len(b) and in_segment(b[j]):
            j += 1
        a_segment, b_segment = a[a_start:i], b[b_start:j]
        if not b_segment:
            # Different segment types: a number is newer than letters.
            return 1 if numeric else -1
        if numeric:
            a_segment, b_segment = a_segment.lstrip("0"), b_segment.lstrip("0")
            if len(a_segment) != len(b_segment):
                return 1 if len(a_segment) > len(b_segment) else -1
        if a_segment != b_segment:
            return 1 if a_segment > b_segment else -1
    if i >= len(a) and j >= len(b):
        return 0
    return 1 if i < len(a) else -1


def evr_cmp(a: Evr, b: Evr) -> int:
    if a[0] != b[0]:
        return 1 if a[0] > b[0] else -1
    return rpmvercmp(a[1], b[1]) or rpmvercmp(a[2], b[2])


evr_key = functools.cmp_to_key(evr_cmp)


def display(evr: Evr) -> str:
    return f"{evr[1]}-{evr[2]}"


def fetch(url: str) -> Optional[bytes]:
    """Return the body at url, or None when it does not exist."""
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        # S3 answers 403 for a missing key in a bucket that cannot be listed.
        if error.code in (403, 404):
            return None
        raise
    except urllib.error.URLError as error:
        if isinstance(error.reason, FileNotFoundError):
            return None
        raise


def parse_package_list(text: str) -> Dict[PackageKey, Evr]:
    """Newest installed build of each package from a saved package list."""
    packages: Dict[PackageKey, Evr] = {}
    for line in text.splitlines():
        if not line.strip():
            continue
        name, epoch, version, release, arch = line.split("\t")
        evr = (int(epoch), version, release)
        key = (name, arch)
        # Several kernels can be installed side by side; the newest one boots.
        if key not in packages or evr_cmp(evr, packages[key]) > 0:
            packages[key] = evr
    return packages


def load_advisories(updateinfo: bytes) -> Tuple[dict, Dict[PackageKey, List[Tuple[Evr, str]]]]:
    """Parse updateinfo.xml.gz into advisory details and a per-package index of fixes."""
    advisories = {}
    fixes: Dict[PackageKey, List[Tuple[Evr, str]]] = collections.defaultdict(list)
    for update in ET.fromstring(gzip.decompress(updateinfo)).findall("update"):
        advisory_id = update.findtext("id")
        title = update.findtext("title") or ""
        advisories[advisory_id] = {
            "severity": update.findtext("severity") or "",
            # "... Important priority package update for kernel6.12"
            "package": title.rsplit(" for ", 1)[-1],
            "cves": sorted({r.get("id") for r in update.iter("reference") if r.get("type") == "cve"}),
        }
        for package in update.iter("package"):
            evr = (int(package.get("epoch") or 0), package.get("version"), package.get("release"))
            fixes[(package.get("name"), package.get("arch"))].append((evr, advisory_id))
    return advisories, fixes


def fetch_updateinfo() -> bytes:
    mirrors = fetch(AL2023_MIRROR_LIST)
    if mirrors is None:
        raise RuntimeError(f"No Amazon Linux mirror list at {AL2023_MIRROR_LIST}")
    repository = mirrors.decode().split()[0]
    repomd = fetch(f"{repository}repodata/repomd.xml")
    if repomd is None:
        raise RuntimeError(f"No repomd.xml under {repository}")
    for data in ET.fromstring(repomd):
        if data.get("type") == "updateinfo":
            for child in data:
                if child.tag.endswith("location"):
                    updateinfo = fetch(repository + child.get("href"))
                    if updateinfo is not None:
                        return updateinfo
    raise RuntimeError(f"No updateinfo in {repository}repodata/repomd.xml")


def is_kernel(name: str) -> bool:
    # kernel (6.1), kernel6.12, kernel6.18: one package name per kernel line.
    return name == "kernel" or (name.startswith("kernel") and name[6:].replace(".", "").isdigit())


def compare(before: Dict[PackageKey, Evr], after: Dict[PackageKey, Evr], fixes) -> Tuple[dict, Optional[tuple]]:
    """Return {advisory: [(package, old, new)]} and any kernel line change."""
    fixed = collections.defaultdict(list)
    for key in sorted(before.keys() & after.keys()):
        old, new = before[key], after[key]
        if evr_cmp(old, new) >= 0:
            continue
        for fix, advisory_id in fixes.get(key, []):
            if evr_cmp(old, fix) < 0 and evr_cmp(fix, new) <= 0:
                entry = (key[0], display(old), display(new))
                if entry not in fixed[advisory_id]:
                    fixed[advisory_id].append(entry)
    old_kernels = {name: evr for (name, _), evr in before.items() if is_kernel(name)}
    new_kernels = {name: evr for (name, _), evr in after.items() if is_kernel(name)}
    kernel_change = None
    if old_kernels and new_kernels and not old_kernels.keys() & new_kernels.keys():
        (old_name, old_evr), (new_name, new_evr) = sorted(old_kernels.items())[0], sorted(new_kernels.items())[0]
        kernel_change = (old_name, display(old_evr), new_name, display(new_evr))
    return fixed, kernel_change


def join_architectures(architectures: Iterable[str]) -> str:
    return " and ".join(ARCHITECTURES[a] for a in ARCHITECTURES if a in architectures)


def render(results: Dict[str, Tuple[dict, Optional[tuple]]], advisories: dict) -> List[str]:
    """Markdown lines for the per-architecture results, merging identical ones."""
    lines = []
    kernel_changes = collections.defaultdict(list)
    for arch, (_, kernel_change) in results.items():
        if kernel_change:
            kernel_changes[kernel_change].append(arch)
    for (old_name, old, new_name, new), architectures in kernel_changes.items():
        lines.append(
            f"- Change the Amazon Linux 2023 kernel from `{old_name}` `{old}` to `{new_name}` `{new}` "
            f"({join_architectures(architectures)}). Fixes are not listed across a change of kernel line."
        )

    # (advisory, lead package, old, new, number of other packages) -> architectures
    updates = collections.defaultdict(list)
    for arch, (fixed, _) in results.items():
        for advisory_id, packages in fixed.items():
            # Name the package the advisory is about when it is installed.
            lead = next((p for p in packages if p[0] == advisories[advisory_id]["package"]), packages[0])
            updates[(advisory_id, *lead, len(packages) - 1)].append(arch)

    def order(item):
        advisory_id = item[0][0]
        severity = advisories[advisory_id]["severity"]
        return (SEVERITIES.index(severity) if severity in SEVERITIES else len(SEVERITIES), advisory_id)

    for (advisory_id, name, old, new, others), architectures in sorted(updates.items(), key=order):
        cves = advisories[advisory_id]["cves"]
        related = f" and {others} related package{'s' if others > 1 else ''}" if others else ""
        link = f"[{advisory_id}]({ADVISORY_URL.format(advisory_id)})"
        line = (
            f"- Update `{name}`{related} from `{old}` to `{new}` in the Amazon Linux 2023 AMIs "
            f"({join_architectures(architectures)}), fixing "
        )
        if len(cves) <= INLINE_CVE_LIMIT:
            lines.append(f"{line}{', '.join(cves)} ({link}).")
        else:
            lines.append(f"{line}{len(cves)} CVEs ({link}).")
            lines.append(f"  <details><summary>CVEs fixed by {advisory_id}</summary>")
            lines.append("")
            lines.append(f"  {', '.join(cves)}")
            lines.append("")
            lines.append("  </details>")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("previous_tag")
    parser.add_argument("release_tag")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="where releases publish their package lists")
    parser.add_argument("--updateinfo", help="URL of an updateinfo.xml.gz to use instead of the Amazon Linux repository's")
    args = parser.parse_args()

    lists = {}
    for arch in ARCHITECTURES:
        pair = []
        for tag in (args.previous_tag, args.release_tag):
            url = f"{args.base_url}/{tag}/packages-linux-{arch}.tsv"
            body = fetch(url)
            if body is None:
                print(f"No package list at {url}; skipping {ARCHITECTURES[arch]}", file=sys.stderr)
                if tag == args.release_tag:
                    print(
                        f"The {tag} release build publishes it when it passes. "
                        "Run this again after that to list the AMI security fixes.",
                        file=sys.stderr,
                    )
                break
            pair.append(parse_package_list(body.decode()))
        else:
            if pair[0] != pair[1]:
                lists[arch] = pair
    if not lists:
        return 0

    if args.updateinfo:
        updateinfo = fetch(args.updateinfo)
        if updateinfo is None:
            raise RuntimeError(f"No advisory file at {args.updateinfo}")
    else:
        updateinfo = fetch_updateinfo()
    advisories, fixes = load_advisories(updateinfo)
    results = {arch: compare(before, after, fixes) for arch, (before, after) in lists.items()}
    for line in render(results, advisories):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
