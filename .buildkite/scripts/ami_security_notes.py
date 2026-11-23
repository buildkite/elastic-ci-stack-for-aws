#!/usr/bin/env python3
"""
Print release-note lines for the security fixes in an Elastic CI Stack
release's Amazon Linux 2023 AMIs that the previous release's notes did not list.

Each release build publishes, next to the CloudFormation template, the date,
the kernel its AMIs booted, their installed packages, and the CVEs Amazon Linux
had published fixes for in those packages, as `dnf updateinfo` reports them (see
.buildkite/steps/save-security-fixes.sh). This script compares two releases'
files and prints the fixes that are new in the later one:

- fixes that came with a package update, and
- fixes Amazon Linux published after the previous release was built, for a
  package build the previous release already had. Amazon Linux often ships a
  package before the advisory that names its CVEs, so these are listed apart, as
  already fixed in the previous release.

It prints nothing when there is no new fix, and when either release has no
file. A release's file exists only once its tag build has published, so run
this after that build passes.

Usage: ami_security_notes.py PREVIOUS_TAG RELEASE_TAG
"""

import argparse
import collections
import re
import sys
import urllib.error
import urllib.request
from typing import Callable, Dict, FrozenSet, Iterable, List, NamedTuple, Optional, Set, Tuple

DEFAULT_BASE_URL = "https://s3.amazonaws.com/buildkite-aws-stack"
ADVISORY_URL = "https://alas.aws.amazon.com/AL2023/{}.html"

# Stack architecture name, as used in file names and release notes.
ARCHITECTURES = {"amd64": "AMD64", "arm64": "ARM64"}
SEVERITIES = ["Critical", "Important", "Medium", "Low"]
# More CVEs than this are collapsed under the line.
OPEN_CVE_LIMIT = 4
# Stands in for the architectures a line applies to until both are compared.
ARCHITECTURE_NAMES = "{architectures}"

# kernel6.12-1:6.12.113-138.209.amzn2023.x86_64 -> kernel6.12, 6.12.113-138.209.amzn2023
PACKAGE_BUILD = re.compile(r"^(?P<package>.+)-(?:\d+:)?(?P<version>[^-]+-[^-]+)\.[^.]+$")


class Fix(NamedTuple):
    package: str
    version: str  # the build that first carried the fix, written as installed versions are
    cve: str  # empty when the advisory names no CVE
    advisories: Tuple[str, ...]
    severity: str


class Fixes(NamedTuple):
    captured: str  # the date the file was saved
    kernel: str  # booted kernel, without the architecture
    packages: Dict[str, Set[str]]  # name -> installed versions
    # (package, version, CVE or advisory without a CVE) -> the fix. Advisories only
    # label a fix: a build can gain a second advisory for CVEs it already listed.
    fixes: Dict[Tuple[str, str, str], Fix]


def parse_fixes(text: str) -> Fixes:
    captured, kernel = "", ""
    packages: Dict[str, Set[str]] = collections.defaultdict(set)
    fixes = {}
    for line in text.splitlines():
        fields = line.split()
        if not fields or fields[0].startswith("#"):
            continue
        if fields[0] == "captured":
            captured = fields[1]
        elif fields[0] == "kernel":
            # 6.12.115-140.210.amzn2023.x86_64
            kernel = re.sub(r"\.(x86_64|aarch64)$", "", fields[1])
        elif fields[0] == "package":
            packages[fields[1]].add(fields[2])
        else:
            # CVE-2026-78659 ALAS2023-2026-3255 Important libcap-2.73-1.amzn2023.0.8.x86_64
            cve, advisories, severity, build = fields
            package, version = PACKAGE_BUILD.match(build).group("package", "version")
            if cve == "-":
                for advisory in advisories.split(","):
                    fixes[(package, version, advisory)] = Fix(package, version, "", (advisory,), severity)
            else:
                fixes[(package, version, cve)] = Fix(package, version, cve, tuple(advisories.split(",")), severity)
    return Fixes(captured, kernel, packages, fixes)


def only(versions: Set[str]) -> Optional[str]:
    return next(iter(versions)) if len(versions) == 1 else None


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


def number(identifier: str) -> List[int]:
    # CVE-2026-98432 -> [2026, 98432], so CVE-2026-98432 sorts before CVE-2026-100072
    return [int(part) for part in identifier.split("-")[1:]]


def kernel_line(before: Fixes, after: Fixes) -> Optional[str]:
    if not before.kernel or not after.kernel or before.kernel == after.kernel:
        return None
    # 6.12 and 6.18 are different packages, so there is no earlier version to compare with.
    same_line = before.kernel.split(".")[:2] == after.kernel.split(".")[:2]
    return (
        f"- {'Update' if same_line else 'Change'} the Amazon Linux 2023 kernel "
        f"from `{before.kernel}` to `{after.kernel}` ({ARCHITECTURE_NAMES})."
        + ("" if same_line else " Kernel fixes are not listed across a change of kernel line; the files linked below list the kernel CVEs Amazon Linux had published fixes for.")
    )


def new_fixes(before: Fixes, after: Fixes) -> Tuple[List[Fix], List[Fix]]:
    """The fixes only `after` lists: those a package update brought, and those the previous release already had."""
    listed_builds = {(package, version) for package, version, _ in before.fixes}
    updated, already_fixed = [], []
    for key, fix in after.fixes.items():
        had = before.packages.get(fix.package)
        # A package that is new to the AMI brings every fix it ever had.
        if key in before.fixes or had is None:
            continue
        # The previous release had this build or a later one when the package did not
        # change, when this is the version it had installed, or when it listed other
        # fixes for the build. Only then was the fix published late.
        if had == after.packages.get(fix.package) or fix.version in had or (fix.package, fix.version) in listed_builds:
            already_fixed.append(fix)
        else:
            updated.append(fix)
    return updated, already_fixed


def fixed_text(cves: FrozenSet[str], advisories: FrozenSet[str], indent: str) -> str:
    """The CVEs and advisory links that end a line; `indent` is the line's list indentation."""
    ids = sorted(advisories, key=number)
    links = ", ".join(f"[{advisory}]({ADVISORY_URL.format(advisory)})" for advisory in ids)
    ordered = sorted(cves, key=number)
    cve_list = "\n".join(f"{indent}  - {cve}" for cve in ordered)
    if not cves:
        # Some advisories name no CVE, so there is only the advisory to point to.
        return f"{links}."
    if len(cves) == 1:
        return f"{ordered[0]} ({links})."
    if len(cves) <= OPEN_CVE_LIMIT:
        return f"{len(cves)} CVEs ({links}):\n{cve_list}"
    return (
        f"{len(cves)} CVEs ({links}).\n"
        f"{indent}  <details><summary>CVEs fixed by {', '.join(ids)}</summary>\n\n"
        f"{cve_list}\n\n"
        f"{indent}  </details>"
    )


def fix_groups(fixes: Iterable[Fix], versions: Callable[[str], str], indent: str = "") -> List[Tuple[int, str, str]]:
    """
    What a line says for each package's fixes: the severity it sorts by, the
    package and what was fixed. Packages with the same fixes and versions, such
    as a kernel and its headers, share a line.
    """
    by_package: Dict[str, List[Fix]] = collections.defaultdict(list)
    for fix in fixes:
        by_package[fix.package].append(fix)
    groups = collections.defaultdict(list)  # what a line says about its packages -> the packages
    for package, found in by_package.items():
        cves = frozenset(fix.cve for fix in found if fix.cve)
        advisories = frozenset(advisory for fix in found for advisory in fix.advisories)
        severity = min(SEVERITIES.index(fix.severity) if fix.severity in SEVERITIES else len(SEVERITIES) for fix in found)
        groups[(severity, versions(package), cves, advisories)].append(package)

    lines = []
    for (severity, version_text, cves, advisories), names in groups.items():
        names.sort(key=lambda name: (len(name), name))
        related = f" and {len(names) - 1} related package{'s' if len(names) > 2 else ''}" if len(names) > 1 else ""
        lines.append((severity, f"`{names[0]}`{related}{version_text}", fixed_text(cves, advisories, indent)))
    return lines


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("previous_tag")
    parser.add_argument("release_tag")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="where releases publish their security fixes")
    args = parser.parse_args()

    # (order, line) -> the architectures it applies to, so identical lines print once
    kernel_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    update_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    late_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    published = {}  # architecture -> the release's published file
    captured = []
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
        if None in texts:
            continue
        published[label] = urls[1]
        before, after = map(parse_fixes, texts)
        captured.append(after.captured)
        line = kernel_line(before, after)
        if line:
            kernel_lines[(0, line)].append(label)
        updated, already_fixed = new_fixes(before, after)

        def version_change(package: str) -> str:
            old, current = only(before.packages[package]), only(after.packages[package])
            return f" from `{old}` to `{current}`" if old and current else ""

        def previous_version(package: str) -> str:
            old = only(before.packages[package])
            return f" at `{old}`" if old else ""

        for severity, packages, fixed in fix_groups(updated, version_change):
            line = f"- Update {packages} in the Amazon Linux 2023 AMIs ({ARCHITECTURE_NAMES}), fixing {fixed}"
            update_lines[(severity, line)].append(label)
        for severity, packages, fixed in fix_groups(already_fixed, previous_version, indent="  "):
            late_lines[(severity, f"  - {packages} ({ARCHITECTURE_NAMES}): {fixed}")].append(label)

    def for_architectures(lines: Dict[Tuple[int, str], List[str]]) -> List[str]:
        return [line.replace(ARCHITECTURE_NAMES, " and ".join(labels)) for (_, line), labels in sorted(lines.items())]

    output = for_architectures(kernel_lines) + for_architectures(update_lines)
    if late_lines:
        output.append(
            f"- Published by Amazon Linux after {args.previous_tag} was built, for packages {args.previous_tag} "
            f"already had, so already fixed in {args.previous_tag} and possibly earlier:"
        )
        output += for_architectures(late_lines)
    if output:
        links = ", ".join(f"[{label}]({url})" for label, url in published.items())
        output.append(
            f"- The CVEs Amazon Linux had published fixes for in these AMIs' packages as of {min(captured)}, "
            f"with advisory and package: {links}."
        )
        print("\n".join(output))
    return 0


if __name__ == "__main__":
    sys.exit(main())
