#!/usr/bin/env python3
"""Offline checks for the AMI security lines added to release notes."""
import gzip
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / ".buildkite/scripts/ami_security_notes.py"

OLD_KERNEL = "6.12.111-136.204.amzn2023"
NEW_KERNEL = "6.12.113-138.209.amzn2023"
RPM_ARCH = {"amd64": "x86_64", "arm64": "aarch64"}

# What `dnf updateinfo list --installed --security` knows: advisory, severity,
# CVEs, and the package builds that carry the fix.
ADVISORIES = {
    "ALAS2023-2026-0001": ("Important", [f"CVE-2026-{n}" for n in range(1000, 1006)],
                           {"kernel6.12": NEW_KERNEL, "kernel6.12-headers": NEW_KERNEL}),
    "ALAS2023-2026-0002": ("Medium", ["CVE-2026-2000"], {"libbrotli": "1.1.0-1.amzn2023.0.10"}),
    "ALAS2023-2026-0003": ("Critical", ["CVE-2026-3000"], {"openssl-libs": "3.5.7-2.amzn2023.0.1"}),
    "ALAS2023-2026-0004": ("Important", ["CVE-2026-4000"], {"curl": "8.21.0-5.amzn2023.0.3"}),
    "ALAS2023-2026-0005": ("Important", ["CVE-2026-5000"], {"kernel6.18": "6.18.56-125.164.amzn2023"}),
    # Amazon publishes some advisories without naming a CVE.
    "ALAS2023-2026-0006": ("Important", [], {"systemd-libs": "252.23-12.amzn2023"}),
    # Two advisories fixed by the same build.
    "ALAS2023-2026-0007": ("Low", ["CVE-2026-7000"], {"amazon-ssm-agent": "3.3.5226.0-1.amzn2023"}),
    "ALAS2023-2026-0008": ("Low", ["CVE-2026-8000"], {"amazon-ssm-agent": "3.3.5226.0-1.amzn2023"}),
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


def security_fixes(arch, kernel, packages, fixed):
    """A file as save-security-fixes.sh writes it, for an AMI where `fixed` advisories apply."""
    lines = [f"kernel {kernel}.{RPM_ARCH[arch]}"]
    lines += [f"package {name} {version}" for name, version in sorted(packages.items())]
    for advisory in fixed:
        severity, cves, builds = ADVISORIES[advisory]
        for name, version in builds.items():
            build = f"{name}-{version}.{RPM_ARCH[arch]}"
            lines.append(f"{advisory}  {severity}/Sec. {build}")
            lines += [f"{cve}  {severity}/Sec. {build}" for cve in cves]
    return "\n".join(lines) + "\n"


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
        published = self.root / tag / f"security-fixes-linux-{arch}.txt.gz"
        published.write_bytes(gzip.compress(security_fixes(arch, kernel, packages, fixed).encode()))

    def run_notes(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "v1.0.0", "v1.1.0", "--base-url", self.root.as_uri()],
            capture_output=True, text=True, check=True,
        )
        return result.stdout.splitlines()

    def all_fixes(self, *architectures):
        links = ", ".join(
            f"[{arch.upper()}]({self.root.as_uri()}/v1.1.0/security-fixes-linux-{arch}.txt.gz)" for arch in architectures
        )
        return f"- Every advisory and CVE these AMIs include a fix for: {links}."

    def test_lists_the_fixes_changed_packages_picked_up(self):
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
                "  CVE-2026-1000, CVE-2026-1001, CVE-2026-1002, CVE-2026-1003, CVE-2026-1004, CVE-2026-1005",
                "",
                "  </details>",
                "- Update `libbrotli` from `1.1.0-1.amzn2023.0.9` to `1.1.0-1.amzn2023.0.10` in the Amazon Linux 2023 AMIs "
                f"(AMD64), fixing CVE-2026-2000 ({link('ALAS2023-2026-0002')}).",
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
                f"2023 AMIs (AMD64), fixing CVE-2026-7000, CVE-2026-8000 ({link('ALAS2023-2026-0007')}, "
                f"{link('ALAS2023-2026-0008')}).",
                self.all_fixes("amd64"),
            ],
        )

    def test_prints_nothing_when_no_package_picked_up_a_fix(self):
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
                "Fixes are not listed across a change of kernel line.",
                self.all_fixes("amd64"),
            ],
        )


if __name__ == "__main__":
    unittest.main()
