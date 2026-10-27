"""Offline regression tests; run with python3 -m unittest discover -s tests/trust."""
import importlib.util
import re
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
TRUST = ROOT / "packer/trust"
spec = importlib.util.spec_from_file_location("trust", TRUST / "check-trust.py")
trust = importlib.util.module_from_spec(spec)
spec.loader.exec_module(trust)


class TrustTests(unittest.TestCase):
    def test_fixture_fingerprints(self):
        self.assertEqual(
            {trust.fingerprint(p.read_text()) for p in (TRUST / "roots").glob("*.crt")},
            trust.BLOCKED,
        )
        self.assertEqual(
            trust.fingerprint((Path(__file__).parent / "isrg-root-x1.crt").read_text()),
            "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6",
        )

    def test_contaminated_bundle_rejected_and_sanitized(self):
        import subprocess
        control = (Path(__file__).parent / "isrg-root-x1.crt").read_text()
        roots = "\n".join(p.read_text() for p in (TRUST / "roots").glob("*.crt"))
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "cacert.pem"
            bundle.write_text(control + roots)
            with self.assertRaisesRegex(AssertionError, "Affected root"):
                trust.check(bundle)
            subprocess.run(["python3", str(TRUST / "check-trust.py"), "--sanitize", str(bundle)], check=True)
            self.assertEqual(trust.PEM.findall(bundle.read_text()), [control.strip()])
            # Re-running the remediation must be safe.
            subprocess.run(["python3", str(TRUST / "check-trust.py"), "--sanitize", str(bundle)], check=True)

    def test_empty_bundle_rejected(self):
        with tempfile.NamedTemporaryFile() as file:
            with self.assertRaisesRegex(AssertionError, "Empty CA bundle"):
                trust.check(Path(file.name))

    def test_all_blocked_bundle_is_not_overwritten(self):
        import subprocess
        roots = "\n".join(p.read_text() for p in (TRUST / "roots").glob("*.crt"))
        with tempfile.TemporaryDirectory() as directory:
            bundle = Path(directory) / "cacert.pem"
            bundle.write_text(roots)
            result = subprocess.run(
                ["python3", str(TRUST / "check-trust.py"), "--sanitize", str(bundle)],
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(bundle.read_text(), roots)

    def test_agent_pins_and_beta(self):
        versions = []
        for platform, extension in [("linux", "sh"), ("windows", "ps1")]:
            installer = (ROOT / f"packer/{platform}/stack/scripts/install-buildkite-agent.{extension}").read_text()
            match = re.search(r'AGENT_VERSION\s*=\s*"(\d+)\.(\d+)\.(\d+)"', installer)
            self.assertIsNotNone(match)
            version = tuple(map(int, match.groups()))
            self.assertGreaterEqual(version, (4, 7, 0))
            versions.append(version)
            self.assertIn("/agent/unstable/latest/", installer)
        self.assertEqual(versions[0], versions[1])

    def test_trust_provisioned_before_downloads(self):
        for platform, extension in [("linux", "sh"), ("windows", "ps1")]:
            packer = (ROOT / f"packer/{platform}/base/base.pkr.hcl").read_text()
            self.assertLess(packer.index(f"scripts/remediate-trust.{extension}"), packer.index(f"scripts/install-utils.{extension}"))


if __name__ == "__main__":
    unittest.main()
