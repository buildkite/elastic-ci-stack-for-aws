#!/usr/bin/env python3
"""Offline checks for the AMI security lines added to release notes."""
import gzip
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".buildkite/scripts/ami_security_notes.py"

spec = importlib.util.spec_from_file_location("ami_security_notes", SCRIPT)
notes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes)


def advisory(advisory_id, severity, source, cves, packages):
    references = "".join(f'<reference id="{cve}" type="cve"/>' for cve in cves)
    entries = "".join(
        f'<package name="{name}" epoch="{epoch}" version="{version}" release="{release}" arch="{arch}"/>'
        for name, epoch, version, release in packages
        for arch in ("x86_64", "aarch64")
    )
    return (
        f'<update type="security"><id>{advisory_id}</id>'
        f"<title>Amazon Linux 2023 - {advisory_id}: {severity} priority package update for {source}</title>"
        f"<severity>{severity}</severity><references>{references}</references>"
        f"<pkglist><collection>{entries}</collection></pkglist></update>"
    )


ADVISORIES = [
    advisory("ALAS2023-2026-0001", "Important", "kernel6.12", [f"CVE-2026-{n}" for n in range(1000, 1006)],
             [("kernel6.12", 1, "6.12.113", "138.209.amzn2023"), ("kernel6.12-headers", 1, "6.12.113", "138.209.amzn2023")]),
    # Fixed in release .10, which sorts after .9 only when compared as numbers.
    advisory("ALAS2023-2026-0002", "Medium", "brotli", ["CVE-2026-2000"], [("libbrotli", 0, "1.1.0", "1.amzn2023.0.10")]),
    advisory("ALAS2023-2026-0003", "Critical", "openssl", ["CVE-2026-3000"], [("openssl-libs", 1, "3.5.7", "2.amzn2023.0.1")]),
    advisory("ALAS2023-2026-0004", "Important", "curl", ["CVE-2026-4000"], [("curl", 0, "8.21.0", "5.amzn2023.0.3")]),
    advisory("ALAS2023-2026-0005", "Important", "firefox", ["CVE-2026-5000"], [("firefox", 0, "153.6.0", "1.amzn2023")]),
    advisory("ALAS2023-2026-0006", "Important", "kernel6.18", ["CVE-2026-6000"], [("kernel6.18", 1, "6.18.56", "125.164.amzn2023")]),
]


def package_list(arch, **overrides):
    packages = {
        "kernel6.12": (1, "6.12.111", "136.204.amzn2023"),
        "kernel6.12-headers": (1, "6.12.111", "136.204.amzn2023"),
        "libbrotli": (0, "1.1.0", "1.amzn2023.0.9"),
        # Already has the openssl fix: the fixed version equals the old version.
        "openssl-libs": (1, "3.5.7", "2.amzn2023.0.1"),
        "curl": (0, "8.21.0", "5.amzn2023.0.1"),
        "jq": (0, "1.8.1", "60.amzn2023"),
    }
    packages.update(overrides)
    return "".join(
        f"{name}\t{epoch}\t{version}\t{release}\t{arch}\n" for name, (epoch, version, release) in sorted(packages.items()) if version
    )


class AmiSecurityNotesTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="ami-security-notes-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.updateinfo = self.root / "updateinfo.xml.gz"
        self.updateinfo.write_bytes(gzip.compress(f"<updates>{''.join(ADVISORIES)}</updates>".encode()))

    def publish(self, tag, amd64=None, arm64=None):
        (self.root / tag).mkdir()
        for arch, rpm_arch, overrides in (("amd64", "x86_64", amd64), ("arm64", "aarch64", arm64)):
            if overrides is not None:
                (self.root / tag / f"packages-linux-{arch}.tsv").write_text(package_list(rpm_arch, **overrides))

    def run_notes(self, previous="v1.0.0", release="v1.1.0"):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), previous, release, "--base-url", self.root.as_uri(), "--updateinfo", self.updateinfo.as_uri()],
            capture_output=True, text=True, check=True,
        )
        return result.stdout

    def test_lists_fixes_between_the_old_and_new_versions(self):
        new_kernel = (1, "6.12.113", "138.209.amzn2023")
        self.publish("v1.0.0", amd64={}, arm64={})
        self.publish(
            "v1.1.0",
            # Lands exactly on the brotli fix, and stops one build short of the curl fix.
            amd64={"kernel6.12": new_kernel, "kernel6.12-headers": new_kernel,
                   "libbrotli": (0, "1.1.0", "1.amzn2023.0.10"), "curl": (0, "8.21.0", "5.amzn2023.0.2"),
                   "openssl-libs": (1, "3.5.8", "1.amzn2023"), "jq": (0, "1.8.1", "61.amzn2023")},
            arm64={"kernel6.12": new_kernel, "kernel6.12-headers": new_kernel},
        )
        self.assertEqual(
            self.run_notes().splitlines(),
            [
                "- Update `kernel6.12` and 1 related package from `6.12.111-136.204.amzn2023` to `6.12.113-138.209.amzn2023` "
                "in the Amazon Linux 2023 AMIs (AMD64 and ARM64), fixing 6 CVEs "
                "([ALAS2023-2026-0001](https://alas.aws.amazon.com/AL2023/ALAS2023-2026-0001.html)).",
                "  <details><summary>CVEs fixed by ALAS2023-2026-0001</summary>",
                "",
                "  CVE-2026-1000, CVE-2026-1001, CVE-2026-1002, CVE-2026-1003, CVE-2026-1004, CVE-2026-1005",
                "",
                "  </details>",
                "- Update `libbrotli` from `1.1.0-1.amzn2023.0.9` to `1.1.0-1.amzn2023.0.10` in the Amazon Linux 2023 AMIs "
                "(AMD64), fixing CVE-2026-2000 ([ALAS2023-2026-0002](https://alas.aws.amazon.com/AL2023/ALAS2023-2026-0002.html)).",
            ],
        )

    def test_prints_nothing_when_no_package_picked_up_a_fix(self):
        self.publish("v1.0.0", amd64={}, arm64={})
        # Same packages on AMD64; an upgrade with no advisory on ARM64.
        self.publish("v1.1.0", amd64={}, arm64={"jq": (0, "1.8.1", "61.amzn2023")})
        self.assertEqual(self.run_notes(), "")

    def test_prints_nothing_when_a_release_has_no_package_list(self):
        self.publish("v1.0.0")
        self.publish("v1.1.0", amd64={"libbrotli": (0, "1.1.0", "1.amzn2023.0.10")}, arm64={})
        self.assertEqual(self.run_notes(), "")

    def test_reports_a_kernel_line_change_without_fixes(self):
        self.publish("v1.0.0", amd64={}, arm64={})
        moved = {"kernel6.12": (0, "", ""), "kernel6.12-headers": (0, "", ""), "kernel6.18": (1, "6.18.56", "125.164.amzn2023")}
        self.publish("v1.1.0", amd64=moved, arm64={})
        self.assertEqual(
            self.run_notes().splitlines(),
            [
                "- Change the Amazon Linux 2023 kernel from `kernel6.12` `6.12.111-136.204.amzn2023` to `kernel6.18` "
                "`6.18.56-125.164.amzn2023` (AMD64). Fixes are not listed across a change of kernel line."
            ],
        )

    def test_rpm_version_comparison(self):
        # Each expected result was checked against rpm 4.16 on Amazon Linux 2023 (rpm.vercmp).
        cases = [
            ("1.0", "1.0", 0), ("1.0", "2.0", -1), ("2.0.1", "2.0", 1), ("5.5p1", "5.5p2", -1), ("5.5p10", "5.5p1", 1),
            ("10xyz", "10.1xyz", -1), ("xyz10", "xyz10.1", -1), ("fc4", "fc.4", 0), ("2a", "2.0", -1), ("1.0", "1.fc4", 1),
            ("1.0~rc1", "1.0", -1), ("1.0~rc1", "1.0~rc2", -1), ("1.0^", "1.0", 1), ("1.0^git1", "1.01", -1),
            ("1.0~rc1^git1", "1.0~rc1", 1), ("0.10", "0.9", 1), ("007", "7", 0),
        ]
        for a, b, expected in cases:
            with self.subTest(a=a, b=b):
                self.assertEqual(notes.rpmvercmp(a, b), expected)
                self.assertEqual(notes.rpmvercmp(b, a), -expected)


if __name__ == "__main__":
    unittest.main()
