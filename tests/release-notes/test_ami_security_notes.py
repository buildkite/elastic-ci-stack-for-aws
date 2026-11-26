"""Run the release-notes helper against small published files, without network calls."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".buildkite/scripts/ami_security_notes.py"


class AmiSecurityNotesTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.published = Path(directory.name)

    def publish(self, tag, arch, kernel, *cves):
        """Write a file as save-security-fixes.sh does; each of cves is "<CVE> <advisory>"."""
        lines = ["# A comment.", "", "captured 2026-11-26", f"kernel {kernel}", ""]
        lines += [f"cve {cve}" for cve in cves] + ["", "package bash 5.2.15-1.amzn2023.0.2"]
        path = self.published / tag / f"security-fixes-linux-{arch}.txt"
        path.parent.mkdir(exist_ok=True)
        path.write_text("\n".join(lines) + "\n")

    def notes(self, previous_tag, release_tag):
        return subprocess.run(
            [SCRIPT, "--base-url", self.published.as_uri(), previous_tag, release_tag],
            capture_output=True,
            text=True,
        )

    def test_lists_each_newly_listed_cve_once_in_numeric_order(self):
        self.publish("v1.0.0", "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.0.0", "arm64", "6.12.1.aarch64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish(
            "v1.1.0",
            "amd64",
            "6.12.2.x86_64",
            "CVE-2026-100 ALAS2023-2026-001",
            # One CVE under two advisories, and again in the other architecture's file.
            "CVE-2026-10000 ALAS2023-2026-003",
            "CVE-2026-10000 ALAS2023-2026-004",
            "CVE-2026-9999 ALAS2023-2026-003",
        )
        self.publish("v1.1.0", "arm64", "6.12.2.aarch64", "CVE-2026-100 ALAS2023-2026-001", "CVE-2026-10000 ALAS2023-2026-003")

        result = self.notes("v1.0.0", "v1.1.0")

        base = self.published.as_uri()
        self.assertEqual(
            result.stdout,
            "- Amazon Linux 2023 booted kernels: AMD64 `6.12.2.x86_64`; ARM64 `6.12.2.aarch64`. Packages and fixed CVEs: "
            f"[AMD64]({base}/v1.1.0/security-fixes-linux-amd64.txt), [ARM64]({base}/v1.1.0/security-fixes-linux-arm64.txt).\n"
            "  <details><summary>2 CVEs newly listed since v1.0.0</summary>\n"
            "\n"
            "  - [CVE-2026-9999](https://explore.alas.aws.amazon.com/CVE-2026-9999.html)\n"
            "  - [CVE-2026-10000](https://explore.alas.aws.amazon.com/CVE-2026-10000.html)\n"
            "\n"
            "  </details>\n",
        )
        self.assertEqual(result.returncode, 0)

    def test_prints_only_the_kernels_when_a_kernel_changed_and_no_cve_is_newly_listed(self):
        self.publish("v1.0.0", "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.0.0", "arm64", "6.12.1.aarch64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.1.0", "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.1.0", "arm64", "6.12.2.aarch64", "CVE-2026-100 ALAS2023-2026-001")

        result = self.notes("v1.0.0", "v1.1.0")

        self.assertEqual(len(result.stdout.splitlines()), 1)
        self.assertIn("AMD64 `6.12.1.x86_64`; ARM64 `6.12.2.aarch64`", result.stdout)
        self.assertEqual(result.returncode, 0)

    def test_prints_nothing_when_the_kernels_are_the_same_and_no_cve_is_newly_listed(self):
        for tag in ("v1.0.0", "v1.1.0"):
            self.publish(tag, "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
            self.publish(tag, "arm64", "6.12.1.aarch64", "CVE-2026-100 ALAS2023-2026-001")

        result = self.notes("v1.0.0", "v1.1.0")

        self.assertEqual(result.stdout, "")
        self.assertEqual(result.returncode, 0)

    def test_fails_until_the_release_has_published_both_files(self):
        self.publish("v1.0.0", "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.0.0", "arm64", "6.12.1.aarch64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.1.0", "amd64", "6.12.2.x86_64", "CVE-2026-200 ALAS2023-2026-002")

        result = self.notes("v1.0.0", "v1.1.0")

        self.assertEqual(result.stdout, "")
        self.assertEqual(result.returncode, 1)
        self.assertIn("v1.1.0 has not published its security fixes for arm64", result.stderr)

    def test_prints_only_the_kernels_when_the_previous_release_lacks_a_file(self):
        self.publish("v1.0.0", "amd64", "6.12.1.x86_64", "CVE-2026-100 ALAS2023-2026-001")
        self.publish("v1.1.0", "amd64", "6.12.2.x86_64", "CVE-2026-200 ALAS2023-2026-002")
        self.publish("v1.1.0", "arm64", "6.12.2.aarch64", "CVE-2026-200 ALAS2023-2026-002")

        result = self.notes("v1.0.0", "v1.1.0")

        self.assertEqual(len(result.stdout.splitlines()), 1)
        self.assertIn("AMD64 `6.12.2.x86_64`; ARM64 `6.12.2.aarch64`", result.stdout)
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
