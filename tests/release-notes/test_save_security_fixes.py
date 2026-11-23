#!/usr/bin/env python3
"""Offline check of the file save-security-fixes.sh writes, with dnf's output stubbed."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

REPOSITORY = Path(__file__).resolve().parents[2]
SAVE = REPOSITORY / ".buildkite/steps/save-security-fixes.sh"
NOTES = REPOSITORY / ".buildkite/scripts/ami_security_notes.py"

# Lines `dnf updateinfo list --installed --security` printed on Amazon Linux 2023:
# one build shared by two advisories, with an epoch, and an advisory that names no CVE.
DNF_ADVISORIES = """\
ALAS2023-2025-988  Medium/Sec.    glibc-2.34-181.amzn2023.0.1.x86_64
ALAS2023-2026-1950 Medium/Sec.    kernel6.12-1:6.12.94-123.174.amzn2023.x86_64
ALAS2023-2026-1968 Important/Sec. kernel6.12-1:6.12.94-123.174.amzn2023.x86_64
ALAS2023-2026-3182 Important/Sec. krb5-libs-1.21.3-8.amzn2023.0.2.x86_64
"""
# The same command with --with-cve.
DNF_CVES = """\
CVE-2025-0395  Medium/Sec.    glibc-2.34-181.amzn2023.0.1.x86_64
CVE-2024-33599 Medium/Sec.    glibc-2.34-181.amzn2023.0.1.x86_64
CVE-2026-46331 Medium/Sec.    kernel6.12-1:6.12.94-123.174.amzn2023.x86_64
CVE-2026-43303 Important/Sec. kernel6.12-1:6.12.94-123.174.amzn2023.x86_64
"""

STUBS = {
    "dnf": 'case "$*" in *--with-cve*) cat "$STUBS/cves" ;; *) cat "$STUBS/advisories" ;; esac',
    "uname": "echo 6.12.111-136.204.amzn2023.x86_64",
    "rpm": textwrap.dedent("""\
        echo package krb5-libs 1.21.3-8.amzn2023.0.2
        echo package kernel6.12 6.12.111-136.204.amzn2023
        echo package glibc 2.34-231.amzn2023.0.1"""),
    "buildkite-agent": 'echo "$*" >"$STUBS/uploaded"',
}


class SaveSecurityFixesTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="save-security-fixes-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        stubs = self.root / "stubs"
        stubs.mkdir()
        for name, body in STUBS.items():
            (stubs / name).write_text(f"#!/bin/sh\n{body}\n")
            (stubs / name).chmod(0o755)
        (stubs / "advisories").write_text(DNF_ADVISORIES)
        (stubs / "cves").write_text(DNF_CVES)
        subprocess.run(
            ["bash", str(SAVE), "linux", "amd64"], cwd=self.root, check=True, capture_output=True,
            env={**os.environ, "PATH": f"{stubs}:{os.environ['PATH']}", "STUBS": str(stubs)},
        )
        self.saved = self.root / "build/security-fixes-linux-amd64.txt"

    def test_puts_each_cve_beside_the_advisories_for_its_build(self):
        self.assertEqual((self.root / "stubs/uploaded").read_text().split(), ["artifact", "upload", str(self.saved.relative_to(self.root))])
        lines = [line for line in self.saved.read_text().splitlines() if line and not line.startswith("#")]
        self.assertRegex(lines[0], r"^captured \d{4}-\d{2}-\d{2}$")
        self.assertEqual(
            lines[1:],
            [
                "kernel 6.12.111-136.204.amzn2023.x86_64",
                "CVE-2024-33599 ALAS2023-2025-988 Medium glibc-2.34-181.amzn2023.0.1.x86_64",
                "CVE-2025-0395 ALAS2023-2025-988 Medium glibc-2.34-181.amzn2023.0.1.x86_64",
                "CVE-2026-43303 ALAS2023-2026-1950,ALAS2023-2026-1968 Important kernel6.12-1:6.12.94-123.174.amzn2023.x86_64",
                "CVE-2026-46331 ALAS2023-2026-1950,ALAS2023-2026-1968 Medium kernel6.12-1:6.12.94-123.174.amzn2023.x86_64",
                "- ALAS2023-2026-3182 Important krb5-libs-1.21.3-8.amzn2023.0.2.x86_64",
                "package glibc 2.34-231.amzn2023.0.1",
                "package kernel6.12 6.12.111-136.204.amzn2023",
                "package krb5-libs 1.21.3-8.amzn2023.0.2",
            ],
        )

    def test_release_notes_read_the_saved_file(self):
        # The previous release had the kernel build these CVEs are fixed in, before
        # Amazon Linux published them. dnf writes that build with an epoch.
        release = self.root / "published/v1.1.0"
        previous = self.root / "published/v1.0.0"
        for directory in (release, previous):
            directory.mkdir(parents=True)
        self.saved.rename(release / self.saved.name)
        (previous / self.saved.name).write_text(textwrap.dedent("""\
            captured 2026-07-01
            kernel 6.12.94-123.174.amzn2023.x86_64
            CVE-2024-33599 ALAS2023-2025-988 Medium glibc-2.34-181.amzn2023.0.1.x86_64
            CVE-2025-0395 ALAS2023-2025-988 Medium glibc-2.34-181.amzn2023.0.1.x86_64
            - ALAS2023-2026-3182 Important krb5-libs-1.21.3-8.amzn2023.0.2.x86_64
            package glibc 2.34-231.amzn2023.0.1
            package kernel6.12 6.12.94-123.174.amzn2023
            package krb5-libs 1.21.3-8.amzn2023.0.2
            """))
        notes = subprocess.run(
            [sys.executable, str(NOTES), "v1.0.0", "v1.1.0", "--base-url", (self.root / "published").as_uri()],
            capture_output=True, text=True, check=True,
        ).stdout.splitlines()
        self.assertEqual(
            notes[:-1],
            [
                "- Update the Amazon Linux 2023 kernel from `6.12.94-123.174.amzn2023` to `6.12.111-136.204.amzn2023` (AMD64).",
                "- Published by Amazon Linux after v1.0.0 was built, for packages v1.0.0 already had, "
                "so already fixed in v1.0.0 and possibly earlier:",
                "  - `kernel6.12` at `6.12.94-123.174.amzn2023` (AMD64): 2 CVEs "
                "([ALAS2023-2026-1950](https://alas.aws.amazon.com/AL2023/ALAS2023-2026-1950.html), "
                "[ALAS2023-2026-1968](https://alas.aws.amazon.com/AL2023/ALAS2023-2026-1968.html)):",
                "    - CVE-2026-43303",
                "    - CVE-2026-46331",
            ],
        )


if __name__ == "__main__":
    unittest.main()
