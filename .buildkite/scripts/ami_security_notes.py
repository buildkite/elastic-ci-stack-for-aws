#!/usr/bin/env python3
"""
Print release-note lines for the security fixes an Elastic CI Stack release
picked up through its Amazon Linux 2023 AMIs.

Each release build publishes, next to the CloudFormation template, the kernel
its AMIs booted, their installed packages, and the Amazon Linux advisories and
CVEs those packages fix, as `dnf updateinfo` reports them (see
.buildkite/steps/save-security-fixes.sh). This script compares two releases'
files and prints the advisories that are new in the later one, for packages
whose installed version changed, and links the later release's files.

It prints nothing when no package picked up a fix, and when either release has
no file. A release's file exists only once its tag build has published, so run
this after that build passes.

Usage: ami_security_notes.py PREVIOUS_TAG RELEASE_TAG
"""

import argparse
import collections
import gzip
import re
import sys
import urllib.error
import urllib.request
from typing import Dict, List, NamedTuple, Optional, Set

DEFAULT_BASE_URL = "https://s3.amazonaws.com/buildkite-aws-stack"
ADVISORY_URL = "https://alas.aws.amazon.com/AL2023/{}.html"

# Stack architecture name, as used in file names and release notes.
ARCHITECTURES = {"amd64": "AMD64", "arm64": "ARM64"}
SEVERITIES = ["Critical", "Important", "Medium", "Low"]
# More CVEs than this are collapsed under the line.
OPEN_CVE_LIMIT = 4
# Stands in for the architectures a line applies to until both are compared.
ARCHITECTURE_NAMES = "{architectures}"


class Fixes(NamedTuple):
    kernel: str  # booted kernel, without the architecture
    packages: Dict[str, Set[str]]  # name -> installed versions
    advisories: Dict[str, Set[str]]  # advisory -> the package builds that fix it
    severities: Dict[str, str]  # advisory -> severity
    cves: Dict[str, Set[str]]  # package build -> CVEs it fixes


def parse_fixes(text: str) -> Fixes:
    fixes = Fixes("", collections.defaultdict(set), collections.defaultdict(set), {}, collections.defaultdict(set))
    for line in text.splitlines():
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if fields[0] == "kernel":
            # 6.12.115-140.210.amzn2023.x86_64
            fixes = fixes._replace(kernel=re.sub(r"\.(x86_64|aarch64)$", "", fields[1]))
        elif fields[0] == "package":
            fixes.packages[fields[1]].add(fields[2])
        else:
            # CVE-2026-78659 ALAS2023-2026-3255 Important libcap-2.73-1.amzn2023.0.8.x86_64
            cve, advisories, severity, build = fields
            # A build that fixes several advisories lists them all.
            for advisory in advisories.split(","):
                fixes.advisories[advisory].add(build)
                fixes.severities[advisory] = severity
            if cve != "-":
                fixes.cves[build].add(cve)
    return fixes


def package_name(build: str) -> str:
    # libcap-2.73-1.amzn2023.0.8.x86_64 -> libcap
    return build.rsplit("-", 2)[0]


def only(versions: Set[str]) -> Optional[str]:
    return next(iter(versions)) if len(versions) == 1 else None


def fetch(url: str) -> Optional[str]:
    """Return the text at url, which is stored gzipped, or None when it does not exist."""
    try:
        with urllib.request.urlopen(url, timeout=60) as response:
            return gzip.decompress(response.read()).decode()
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return None
        raise
    except urllib.error.URLError as error:
        if isinstance(error.reason, FileNotFoundError):
            return None
        raise


def cve_number(cve: str) -> List[int]:
    # CVE-2026-98432 -> [2026, 98432], so CVE-2026-98432 sorts before CVE-2026-100072
    return [int(part) for part in cve.split("-")[1:]]


def kernel_line(before: Fixes, after: Fixes) -> Optional[str]:
    if not before.kernel or not after.kernel or before.kernel == after.kernel:
        return None
    # 6.12 and 6.18 are different packages, so there is no earlier version to compare with.
    same_line = before.kernel.split(".")[:2] == after.kernel.split(".")[:2]
    return (
        f"- {'Update' if same_line else 'Change'} the Amazon Linux 2023 kernel "
        f"from `{before.kernel}` to `{after.kernel}` ({ARCHITECTURE_NAMES})."
        + ("" if same_line else " Kernel fixes are not listed across a change of kernel line; the files linked below list every kernel CVE these AMIs include a fix for.")
    )


def advisory_lines(before: Fixes, after: Fixes) -> Dict[str, List[str]]:
    """Release-note lines, keyed by severity, for the advisories new in `after`."""
    # Advisories fixed by the same package builds share one line.
    new: Dict[frozenset, List[str]] = collections.defaultdict(list)
    for advisory, builds in sorted(after.advisories.items()):
        changed = frozenset(
            build
            for build in builds - before.advisories.get(advisory, set())
            # A package that is new to the AMI brings every fix it ever had, and
            # an unchanged one has only had its advisory published late.
            if before.packages.get(package_name(build)) not in (None, after.packages.get(package_name(build)))
        )
        if changed:
            new[changed].append(advisory)

    lines = collections.defaultdict(list)
    for builds, advisories in new.items():
        names = sorted({package_name(build) for build in builds}, key=lambda name: (len(name), name))
        related = f" and {len(names) - 1} related package{'s' if len(names) > 2 else ''}" if len(names) > 1 else ""
        old, current = only(before.packages[names[0]]), only(after.packages[names[0]])
        versions = f" from `{old}` to `{current}`" if old and current else ""
        cves = sorted(set().union(*(after.cves.get(build, set()) for build in builds)), key=cve_number)
        links = ", ".join(f"[{advisory}]({ADVISORY_URL.format(advisory)})" for advisory in advisories)
        line = f"- Update `{names[0]}`{related}{versions} in the Amazon Linux 2023 AMIs ({ARCHITECTURE_NAMES}), fixing "
        cve_list = "\n".join(f"  - {cve}" for cve in cves)
        if not cves:
            # Some advisories name no CVE, so there is only the advisory to point to.
            line += f"{links}."
        elif len(cves) == 1:
            line += f"{cves[0]} ({links})."
        elif len(cves) <= OPEN_CVE_LIMIT:
            line += f"{len(cves)} CVEs ({links}):\n{cve_list}"
        else:
            line += (
                f"{len(cves)} CVEs ({links}).\n"
                f"  <details><summary>CVEs fixed by {', '.join(advisories)}</summary>\n\n"
                f"{cve_list}\n\n"
                "  </details>"
            )
        lines[after.severities[advisories[0]]].append(line)
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("previous_tag")
    parser.add_argument("release_tag")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="where releases publish their security fixes")
    args = parser.parse_args()

    # line -> the architectures it applies to, so identical lines print once
    kernel_lines: Dict[str, List[str]] = collections.defaultdict(list)
    fix_lines: Dict[str, Dict[str, List[str]]] = collections.defaultdict(lambda: collections.defaultdict(list))
    published = {}  # architecture -> the release's published file
    for arch, label in ARCHITECTURES.items():
        urls = [f"{args.base_url}/{tag}/security-fixes-linux-{arch}.txt" for tag in (args.previous_tag, args.release_tag)]
        texts = [fetch(url) for url in urls]
        for url, text in zip(urls, texts):
            if text is None:
                print(f"No security fixes at {url}; skipping {label}", file=sys.stderr)
        if texts[1] is None:
            print(
                f"The {args.release_tag} release build publishes them when it passes. "
                "Run this again after that to list the AMI security fixes.",
                file=sys.stderr,
            )
        if None not in texts:
            published[label] = urls[1]
            before, after = map(parse_fixes, texts)
            line = kernel_line(before, after)
            if line:
                kernel_lines[line].append(label)
            for severity, lines in advisory_lines(before, after).items():
                for line in lines:
                    fix_lines[severity][line].append(label)

    def for_architectures(lines: Dict[str, List[str]]) -> List[str]:
        return [line.replace(ARCHITECTURE_NAMES, " and ".join(labels)) for line, labels in sorted(lines.items())]

    output = for_architectures(kernel_lines)
    for severity in SEVERITIES + sorted(set(fix_lines) - set(SEVERITIES)):
        output += for_architectures(fix_lines.get(severity, {}))
    if output:
        links = ", ".join(f"[{label}]({url})" for label, url in published.items())
        output.append(f"- Every CVE these AMIs include a fix for, with its advisory and package: {links}.")
        print("\n".join(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
