#!/usr/bin/env python3
"""Offline checks for the AMI security lines added to release notes."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / ".buildkite/scripts/ami_security_notes.py"

OLD_KERNEL = "6.12.111-136.204.amzn2023"
NEW_KERNEL = "6.12.113-138.209.amzn2023"
RPM_ARCH = {"amd64": "x86_64", "arm64": "aarch64"}

# What Amazon Linux knows about each advisory: severity, CVEs, and the package
# builds that carry the fix.
ADVISORIES = {
    "ALAS2023-2026-0001": ("Important", [f"CVE-2026-{n}" for n in range(1000, 1006)],
                           {"kernel6.12": NEW_KERNEL, "kernel6.12-headers": NEW_KERNEL}),
    "ALAS2023-2026-0002": ("Medium", ["CVE-2026-2000"], {"libbrotli": "1.1.0-1.amzn2023.0.10"}),
    "ALAS2023-2026-0003": ("Critical", ["CVE-2026-3000"], {"openssl-libs": "3.5.7-2.amzn2023.0.1"}),
    "ALAS2023-2026-0004": ("Important", ["CVE-2026-4000"], {"curl": "8.21.0-5.amzn2023.0.3"}),
    "ALAS2023-2026-0005": ("Important", ["CVE-2026-5000"], {"kernel6.18": "6.18.56-125.164.amzn2023"}),
    # Amazon publishes some advisories without naming a CVE.
    "ALAS2023-2026-0006": ("Important", [], {"systemd-libs": "252.23-12.amzn2023"}),
    # Two advisories fixed by the same build. Sorting their CVEs as text would put 10000 first.
    "ALAS2023-2026-0007": ("Low", ["CVE-2026-10000", "CVE-2026-7000"], {"amazon-ssm-agent": "3.3.5226.0-1.amzn2023"}),
    "ALAS2023-2026-0008": ("Low", ["CVE-2026-8000"], {"amazon-ssm-agent": "3.3.5226.0-1.amzn2023"}),
    # Fixed by the kernel the previous release had.
    "ALAS2023-2026-0009": ("Important", [f"CVE-2026-{n}" for n in range(9000, 9005)],
                           {"kernel6.12": OLD_KERNEL, "kernel6.12-headers": OLD_KERNEL}),
    # Two advisories fixed by a libbrotli build older than the one the previous release had.
    "ALAS2023-2026-0010": ("Medium", ["CVE-2026-1100"], {"libbrotli": "1.1.0-1.amzn2023.0.8"}),
    "ALAS2023-2026-0011": ("Medium", ["CVE-2026-1101"], {"libbrotli": "1.1.0-1.amzn2023.0.8"}),
}

PREVIOUS_PACKAGES = {
    "kernel6.12": OLD_KERNEL,
    "kernel6.12-headers": OLD_KERNEL,
    "libbrotli": "1.1.0-1.amzn2023.0.9",
    "openssl-libs": "3.5.7-2.amzn2023.0.1",
    "curl": "8.21.0-5.amzn2023.0.3",
    "systemd-libs": "252.23-11.amzn2023",
    "amazon-ssm-agent": "3.3.4624.0-1.amzn2023",
    "jq": "1.8.1-60.amzn2023",
}


def security_fixes(arch, captured, kernel, packages, fixed):
    """A file as save-security-fixes.sh writes it, for an AMI where `fixed` advisories apply."""
    by_build = {}  # package build -> its advisories, severity and CVEs
    for advisory in fixed:
        severity, cves, builds = ADVISORIES[advisory]
        for name, version in builds.items():
            # dnf prints the epoch of a build that has one, as kernels do.
            epoch = "1:" if name.startswith("kernel") else ""
            entry = by_build.setdefault(f"{name}-{epoch}{version}.{RPM_ARCH[arch]}", ([], severity, []))
            entry[0].append(advisory)
            entry[2].extend(cves)
    lines = ["# Security fixes in this Elastic CI Stack for AWS AMI.", "", f"captured {captured}",
             f"kernel {kernel}.{RPM_ARCH[arch]}", ""]
    for build, (advisories, severity, cves) in by_build.items():
        lines += [f"{cve} {','.join(advisories)} {severity} {build}" for cve in cves or ["-"]]
    lines += [""] + [f"package {name} {version}" for name, version in sorted(packages.items())]
    return "\n".join(lines) + "\n"


ALREADY_FIXED = (
    "- Published by Amazon Linux after v1.0.0 was built, for packages v1.0.0 already had, "
    "so already fixed in v1.0.0 and possibly earlier:"
)


def link(advisory):
    return f"[{advisory}](https://alas.aws.amazon.com/AL2023/{advisory}.html)"


class AmiSecurityNotesTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="ami-security-notes-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)

    def publish(self, tag, arch, kernel=OLD_KERNEL, fixed=("ALAS2023-2026-0003",), **changed):
        """Publish a release's file for one architecture; the defaults are the previous release."""
        packages = {name: version for name, version in {**PREVIOUS_PACKAGES, **changed}.items() if version}
        (self.root / tag).mkdir(exist_ok=True)
        captured = "2026-10-20" if tag == "v1.0.0" else "2026-11-02"
        published = self.root / tag / f"security-fixes-linux-{arch}.txt"
        published.write_text(security_fixes(arch, captured, kernel, packages, fixed))

    def run_notes(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "v1.0.0", "v1.1.0", "--base-url", self.root.as_uri()],
            capture_output=True, text=True, check=True,
        )
        return result.stdout.splitlines()

    def all_fixes(self, *architectures):
        links = ", ".join(
            f"[{arch.upper()}]({self.root.as_uri()}/v1.1.0/security-fixes-linux-{arch}.txt)" for arch in architectures
        )
        return (
            "- The CVEs Amazon Linux had published fixes for in these AMIs' packages as of 2026-11-02, "
            f"with advisory and package: {links}."
        )

    def test_lists_the_fixes_updated_packages_brought_apart_from_those_published_late(self):
        for arch in ("amd64", "arm64"):
            self.publish("v1.0.0", arch)
        self.publish(
            "v1.1.0", "amd64", kernel=NEW_KERNEL,
            # The curl advisory was published late for a build this AMI already had.
            fixed=["ALAS2023-2026-0001", "ALAS2023-2026-0002", "ALAS2023-2026-0003", "ALAS2023-2026-0004"],
            **{"kernel6.12": NEW_KERNEL, "kernel6.12-headers": NEW_KERNEL, "libbrotli": "1.1.0-1.amzn2023.0.10",
               "jq": "1.8.1-61.amzn2023"},
        )
        self.publish(
            "v1.1.0", "arm64", kernel=NEW_KERNEL, fixed=["ALAS2023-2026-0001", "ALAS2023-2026-0003"],
            **{"kernel6.12": NEW_KERNEL, "kernel6.12-headers": NEW_KERNEL},
        )
        self.assertEqual(
            self.run_notes(),
            [
                f"- Update the Amazon Linux 2023 kernel from `{OLD_KERNEL}` to `{NEW_KERNEL}` (AMD64 and ARM64).",
                f"- Update `kernel6.12` and 1 related package from `{OLD_KERNEL}` to `{NEW_KERNEL}` "
                f"in the Amazon Linux 2023 AMIs (AMD64 and ARM64), fixing 6 CVEs ({link('ALAS2023-2026-0001')}).",
                "  <details><summary>CVEs fixed by ALAS2023-2026-0001</summary>",
                "",
                "  - CVE-2026-1000",
                "  - CVE-2026-1001",
                "  - CVE-2026-1002",
                "  - CVE-2026-1003",
                "  - CVE-2026-1004",
                "  - CVE-2026-1005",
                "",
                "  </details>",
                "- Update `libbrotli` from `1.1.0-1.amzn2023.0.9` to `1.1.0-1.amzn2023.0.10` in the Amazon Linux 2023 AMIs "
                f"(AMD64), fixing CVE-2026-2000 ({link('ALAS2023-2026-0002')}).",
                ALREADY_FIXED,
                f"  - `curl` at `8.21.0-5.amzn2023.0.3` (AMD64): CVE-2026-4000 ({link('ALAS2023-2026-0004')}).",
                self.all_fixes("amd64", "arm64"),
            ],
        )

    def test_names_the_advisory_when_it_lists_no_cve_and_joins_advisories_fixed_by_one_build(self):
        self.publish("v1.0.0", "amd64")
        self.publish(
            "v1.1.0", "amd64",
            fixed=["ALAS2023-2026-0003", "ALAS2023-2026-0006", "ALAS2023-2026-0007", "ALAS2023-2026-0008"],
            **{"systemd-libs": "252.23-12.amzn2023", "amazon-ssm-agent": "3.3.5226.0-1.amzn2023"},
        )
        self.assertEqual(
            self.run_notes(),
            [
                "- Update `systemd-libs` from `252.23-11.amzn2023` to `252.23-12.amzn2023` in the Amazon Linux 2023 AMIs "
                f"(AMD64), fixing {link('ALAS2023-2026-0006')}.",
                "- Update `amazon-ssm-agent` from `3.3.4624.0-1.amzn2023` to `3.3.5226.0-1.amzn2023` in the Amazon Linux "
                f"2023 AMIs (AMD64), fixing 3 CVEs ({link('ALAS2023-2026-0007')}, {link('ALAS2023-2026-0008')}):",
                "  - CVE-2026-7000",
                "  - CVE-2026-8000",
                "  - CVE-2026-10000",
                self.all_fixes("amd64"),
            ],
        )

    def test_does_not_credit_an_update_with_fixes_the_previous_release_already_had(self):
        self.publish("v1.0.0", "amd64", fixed=["ALAS2023-2026-0003", "ALAS2023-2026-0010"])
        self.publish(
            "v1.1.0", "amd64", kernel=NEW_KERNEL,
            # Since v1.0.0, Amazon Linux has published 0009 for the kernel v1.0.0 had,
            # and 0011 for a libbrotli build v1.0.0 already listed a fix for.
            fixed=["ALAS2023-2026-0001", "ALAS2023-2026-0002", "ALAS2023-2026-0003", "ALAS2023-2026-0009",
                   "ALAS2023-2026-0010", "ALAS2023-2026-0011"],
            **{"kernel6.12": NEW_KERNEL, "kernel6.12-headers": NEW_KERNEL, "libbrotli": "1.1.0-1.amzn2023.0.10"},
        )
        self.assertEqual(
            self.run_notes(),
            [
                f"- Update the Amazon Linux 2023 kernel from `{OLD_KERNEL}` to `{NEW_KERNEL}` (AMD64).",
                f"- Update `kernel6.12` and 1 related package from `{OLD_KERNEL}` to `{NEW_KERNEL}` "
                f"in the Amazon Linux 2023 AMIs (AMD64), fixing 6 CVEs ({link('ALAS2023-2026-0001')}).",
                "  <details><summary>CVEs fixed by ALAS2023-2026-0001</summary>",
                "",
                "  - CVE-2026-1000",
                "  - CVE-2026-1001",
                "  - CVE-2026-1002",
                "  - CVE-2026-1003",
                "  - CVE-2026-1004",
                "  - CVE-2026-1005",
                "",
                "  </details>",
                "- Update `libbrotli` from `1.1.0-1.amzn2023.0.9` to `1.1.0-1.amzn2023.0.10` in the Amazon Linux 2023 AMIs "
                f"(AMD64), fixing CVE-2026-2000 ({link('ALAS2023-2026-0002')}).",
                ALREADY_FIXED,
                f"  - `kernel6.12` and 1 related package at `{OLD_KERNEL}` (AMD64): 5 CVEs ({link('ALAS2023-2026-0009')}).",
                "    <details><summary>CVEs fixed by ALAS2023-2026-0009</summary>",
                "",
                "    - CVE-2026-9000",
                "    - CVE-2026-9001",
                "    - CVE-2026-9002",
                "    - CVE-2026-9003",
                "    - CVE-2026-9004",
                "",
                "    </details>",
                "  - `libbrotli` at `1.1.0-1.amzn2023.0.9` (AMD64): CVE-2026-1101 "
                f"({link('ALAS2023-2026-0010')}, {link('ALAS2023-2026-0011')}).",
                self.all_fixes("amd64"),
            ],
        )

    def test_lists_only_the_new_cves_when_a_build_gains_a_second_advisory(self):
        ssm_agent = {"amazon-ssm-agent": "3.3.5226.0-1.amzn2023"}
        self.publish("v1.0.0", "amd64", fixed=["ALAS2023-2026-0003", "ALAS2023-2026-0007"], **ssm_agent)
        self.publish(
            "v1.1.0", "amd64", fixed=["ALAS2023-2026-0003", "ALAS2023-2026-0007", "ALAS2023-2026-0008"], **ssm_agent
        )
        self.assertEqual(
            self.run_notes(),
            [
                ALREADY_FIXED,
                "  - `amazon-ssm-agent` at `3.3.5226.0-1.amzn2023` (AMD64): CVE-2026-8000 "
                f"({link('ALAS2023-2026-0007')}, {link('ALAS2023-2026-0008')}).",
                self.all_fixes("amd64"),
            ],
        )

    def test_prints_nothing_when_there_is_no_new_fix(self):
        for arch in ("amd64", "arm64"):
            self.publish("v1.0.0", arch)
        self.publish("v1.1.0", "amd64")
        # An upgrade with no advisory.
        self.publish("v1.1.0", "arm64", jq="1.8.1-61.amzn2023")
        self.assertEqual(self.run_notes(), [])

    def test_prints_nothing_when_a_release_has_no_file(self):
        self.publish("v1.1.0", "amd64", fixed=["ALAS2023-2026-0002", "ALAS2023-2026-0003"], libbrotli="1.1.0-1.amzn2023.0.10")
        self.publish("v1.0.0", "arm64")
        self.assertEqual(self.run_notes(), [])

    def test_reports_a_kernel_line_change_without_the_new_line_s_past_fixes(self):
        self.publish("v1.0.0", "amd64")
        self.publish(
            "v1.1.0", "amd64", kernel="6.18.56-125.164.amzn2023", fixed=["ALAS2023-2026-0003", "ALAS2023-2026-0005"],
            **{"kernel6.12": None, "kernel6.12-headers": None, "kernel6.18": "6.18.56-125.164.amzn2023"},
        )
        self.assertEqual(
            self.run_notes(),
            [
                f"- Change the Amazon Linux 2023 kernel from `{OLD_KERNEL}` to `6.18.56-125.164.amzn2023` (AMD64). "
                "Kernel fixes are not listed across a change of kernel line; the files linked below list the kernel CVEs "
                "Amazon Linux had published fixes for.",
                self.all_fixes("amd64"),
            ],
        )


if __name__ == "__main__":
    unittest.main()
