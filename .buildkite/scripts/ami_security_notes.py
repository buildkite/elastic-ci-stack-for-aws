#!/usr/bin/env python3
"""
Print release-note lines for the Amazon Linux security advisories an Elastic CI
Stack release's Amazon Linux 2023 AMIs newly include.

Each release build publishes, next to the CloudFormation template, the date,
the kernel its AMIs booted, their installed packages, and the Amazon Linux
advisories those packages include, as `dnf updateinfo` reports them (see
.buildkite/steps/save-security-fixes.sh). This script compares two releases'
files and prints, with a link to each advisory:

- the advisories that came with a package update, and
- the advisories Amazon Linux published after the previous release was built,
  for a package build the previous release already had. Amazon Linux often
  ships a package before its advisory, so these are listed apart, as already
  fixed in the previous release.

The advisory pages list the CVEs, and Amazon Linux keeps them up to date.

A release's files exist only once its tag build has published them, and
release notes are usually written before that. Until then this compares the
previous release with the branch the release is tagged on. When the branch has
new advisories it prints one line that links the files and the page of new
advisories the release build will publish. Once both releases have their files
it prints the new advisories themselves. Either way it prints nothing when
nothing is new.

With --page it prints that page for the release build to publish: the same
lines under a heading, and a line saying so when nothing is new.

Usage: ami_security_notes.py [--page] PREVIOUS_TAG RELEASE_TAG
"""

import argparse
import collections
import re
import sys
import urllib.error
import urllib.request
from typing import Callable, Dict, Iterable, List, NamedTuple, Optional, Set, Tuple

DEFAULT_BASE_URL = "https://s3.amazonaws.com/buildkite-aws-stack"
ADVISORY_URL = "https://alas.aws.amazon.com/AL2023/{}.html"

# Stack architecture name, as used in file names and release notes.
ARCHITECTURES = {"amd64": "AMD64", "arm64": "ARM64"}
SEVERITIES = ["Critical", "Important", "Medium", "Low"]
# Stands in for the architectures a line applies to until both are compared.
ARCHITECTURE_NAMES = "{architectures}"
# The release build publishes this script's --page output under this name, beside the files.
NEW_FIXES_PAGE = "security-fixes-linux-new.md"

# kernel6.12-1:6.12.113-138.209.amzn2023.x86_64 -> kernel6.12, 6.12.113-138.209.amzn2023
PACKAGE_BUILD = re.compile(r"^(?P<package>.+)-(?:\d+:)?(?P<version>[^-]+-[^-]+)\.[^.]+$")


class Fix(NamedTuple):
    package: str
    version: str  # the build the advisory names, written as installed versions are
    advisory: str
    severity: str


class Fixes(NamedTuple):
    captured: str  # the date the file was saved
    kernel: str  # booted kernel, without the architecture
    packages: Dict[str, Set[str]]  # name -> installed versions
    fixes: Set[Fix]


def parse_fixes(text: str) -> Fixes:
    captured, kernel = "", ""
    packages: Dict[str, Set[str]] = collections.defaultdict(set)
    fixes = set()
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
        elif fields[0] == "advisory":
            # advisory ALAS2023-2026-3255 Important libcap-2.73-1.amzn2023.0.8.x86_64
            _, advisory, severity, build = fields
            package, version = PACKAGE_BUILD.match(build).group("package", "version")
            fixes.add(Fix(package, version, advisory, severity))
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


def number(advisory: str) -> List[int]:
    # ALAS2023-2026-998 -> [2026, 998], so it sorts before ALAS2023-2026-3335
    return [int(part) for part in advisory.split("-")[1:]]


def kernel_line(before: Fixes, after: Fixes) -> Optional[str]:
    if not before.kernel or not after.kernel or before.kernel == after.kernel:
        return None
    # 6.12 and 6.18 are different packages, so there is no earlier version to compare with.
    same_line = before.kernel.split(".")[:2] == after.kernel.split(".")[:2]
    return (
        f"- {'Update' if same_line else 'Change'} the Amazon Linux 2023 kernel "
        f"from `{before.kernel}` to `{after.kernel}` ({ARCHITECTURE_NAMES})."
        + ("" if same_line else " Advisories are not listed across a change of kernel line; the files linked below list the new kernel's.")
    )


def new_fixes(before: Fixes, after: Fixes) -> Tuple[List[Fix], List[Fix]]:
    """The advisories only `after` lists: those a package update brought, and those the previous release already had."""
    listed_builds = {(fix.package, fix.version) for fix in before.fixes}
    updated, already_fixed = [], []
    for fix in after.fixes - before.fixes:
        had = before.packages.get(fix.package)
        # A package that is new to the AMI brings every advisory it ever had.
        if had is None:
            continue
        # The previous release had this build or a later one when the package did not
        # change, when this is the version it had installed, or when it listed another
        # advisory for the build. Only then was the advisory published late.
        if had == after.packages.get(fix.package) or fix.version in had or (fix.package, fix.version) in listed_builds:
            already_fixed.append(fix)
        else:
            updated.append(fix)
    return updated, already_fixed


def fix_groups(fixes: Iterable[Fix], versions: Callable[[str], str]) -> List[Tuple[int, str, str]]:
    """
    What a line says for each package's advisories: the severity it sorts by, the
    package and links to the advisories. Packages with the same advisories and
    versions, such as a kernel and its headers, share a line.
    """
    by_package: Dict[str, Dict[str, str]] = collections.defaultdict(dict)  # package -> advisory -> severity
    for fix in fixes:
        by_package[fix.package][fix.advisory] = fix.severity
    groups = collections.defaultdict(list)  # what a line says about its packages -> the packages
    for package, advisories in by_package.items():
        groups[(versions(package), tuple(sorted(advisories.items(), key=lambda item: number(item[0]))))].append(package)

    lines = []
    for (version_text, advisories), names in groups.items():
        names.sort(key=lambda name: (len(name), name))
        related = f" and {len(names) - 1} related package{'s' if len(names) > 2 else ''}" if len(names) > 1 else ""
        links = ", ".join(f"[{advisory}]({ADVISORY_URL.format(advisory)}) ({severity})" for advisory, severity in advisories)
        most_severe = min(SEVERITIES.index(severity) if severity in SEVERITIES else len(SEVERITIES) for _, severity in advisories)
        lines.append((most_severe, f"`{names[0]}`{related}{version_text}", links))
    return lines


def new_fix_lines(previous_tag: str, before: Dict[str, Fixes], after: Dict[str, Fixes]) -> List[str]:
    """The lines for what is new in `after`; both map an architecture's name to its fixes."""
    # (order, line) -> the architectures it applies to, so identical lines print once
    kernel_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    update_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    late_lines: Dict[Tuple[int, str], List[str]] = collections.defaultdict(list)
    for label in after:
        old, new = before[label], after[label]
        line = kernel_line(old, new)
        if line:
            kernel_lines[(0, line)].append(label)
        updated, already_fixed = new_fixes(old, new)

        def version_change(package: str) -> str:
            was, now = only(old.packages[package]), only(new.packages[package])
            return f" from `{was}` to `{now}`" if was and now else ""

        def previous_version(package: str) -> str:
            was = only(old.packages[package])
            return f" at `{was}`" if was else ""

        for severity, packages, links in fix_groups(updated, version_change):
            line = f"- Update {packages} in the Amazon Linux 2023 AMIs ({ARCHITECTURE_NAMES}), fixing {links}."
            update_lines[(severity, line)].append(label)
        for severity, packages, links in fix_groups(already_fixed, previous_version):
            late_lines[(severity, f"  - {packages} ({ARCHITECTURE_NAMES}): {links}.")].append(label)

    def for_architectures(lines: Dict[Tuple[int, str], List[str]]) -> List[str]:
        return [line.replace(ARCHITECTURE_NAMES, " and ".join(labels)) for (_, line), labels in sorted(lines.items())]

    output = for_architectures(kernel_lines) + for_architectures(update_lines)
    if late_lines:
        output.append(
            f"- Published by Amazon Linux after {previous_tag} was built, for package versions {previous_tag} "
            f"already had, so already fixed in {previous_tag} and possibly earlier:"
        )
        output += for_architectures(late_lines)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("previous_tag")
    parser.add_argument("release_tag")
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL, help="where releases publish their security fixes")
    parser.add_argument("--branch", default="main", help="the branch the release is tagged on (default: %(default)s)")
    parser.add_argument("--page", action="store_true", help=f"print the page a release build publishes as {NEW_FIXES_PAGE}")
    args = parser.parse_args()

    def urls(name: str) -> Dict[str, str]:
        return {label: f"{args.base_url}/{name}/security-fixes-linux-{arch}.txt" for arch, label in ARCHITECTURES.items()}

    def published(name: str) -> Optional[Dict[str, Fixes]]:
        """A tag or branch's fixes for each architecture, when it has published them all."""
        texts = {label: fetch(url) for label, url in urls(name).items()}
        if None in texts.values():
            print(f"{name} has not published its security fixes for every architecture.", file=sys.stderr)
            return None
        return {label: parse_fixes(text) for label, text in texts.items()}

    files = ", ".join(f"[{label}]({url})" for label, url in urls(args.release_tag).items())
    previous, release = published(args.previous_tag), published(args.release_tag)

    if args.page:
        if not release:
            return 1
        print(f"# Security fixes new in the Amazon Linux 2023 AMIs of Elastic CI Stack for AWS {args.release_tag}\n")
        if previous:
            lines = new_fix_lines(args.previous_tag, previous, release) or [f"- No advisory is new since {args.previous_tag}."]
        else:
            lines = [f"- {args.previous_tag} published no security fixes, so there is nothing to compare with."]
    elif not previous:
        return 0
    elif release:
        lines = new_fix_lines(args.previous_tag, previous, release)
    else:
        # Release notes are usually written before the release build runs. Its AMIs take their packages from
        # the base AMIs built on the branch, so what is new on the branch is new in the release. The release
        # build publishes the files and the page, so they can be linked now.
        branch = published(args.branch)
        if branch and new_fix_lines(args.previous_tag, previous, branch):
            print(
                f"- Kernel and security updates in this release's Amazon Linux 2023 AMIs: [new since {args.previous_tag}]"
                f"({args.base_url}/{args.release_tag}/{NEW_FIXES_PAGE}). Their kernel, package versions and "
                f"Amazon Linux advisories: {files}."
            )
        return 0
    if lines:
        captured = min(fixes.captured for fixes in release.values())
        lines.append(
            f"- The kernel, package versions and Amazon Linux advisories of these AMIs as of {captured}: {files}."
        )
        print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
