#!/usr/bin/env python3
"""Credential-free checks for Linux base upload paths and their consumers."""
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "packer/linux/base"
SHARED = ROOT / "packer/linux/shared"


class BaseStagingTest(unittest.TestCase):
    def setUp(self):
        self.hcl = (BASE / "base.pkr.hcl").read_text()
        self.temp = tempfile.TemporaryDirectory(prefix="base-staging-")
        self.addCleanup(self.temp.cleanup)
        # Exercise quoting too, not just the production path.
        self.staging = Path(self.temp.name) / "packer assets"
        self.inline = re.findall(r'inline\s*= \["([^"]+)"\]', self.hcl)

    def run_inline(self, index):
        command = self.inline[index].replace("${local.staging_dir}", str(self.staging))
        return subprocess.run(["bash", "-eu", "-c", command], capture_output=True)

    def stage(self):
        self.assertEqual(self.run_inline(0).returncode, 0)
        shutil.copytree(BASE / "conf", self.staging / "conf")
        shutil.copytree(SHARED / "conf", self.staging / "conf", dirs_exist_ok=True)
        shutil.copy(BASE / "scripts/versions.sh", self.staging)
        shutil.copy(SHARED / "scripts/distro.sh", self.staging)

    def test_private_staging_and_cleanup(self):
        self.stage()
        self.assertEqual(stat.S_IMODE(self.staging.stat().st_mode), 0o700)
        # Never adopt an existing directory, even if writable by other users.
        self.staging.chmod(0o777)
        self.assertNotEqual(self.run_inline(0).returncode, 0)
        self.assertEqual(self.run_inline(-1).returncode, 0)
        self.assertFalse(self.staging.exists())
        target = Path(self.temp.name) / "target"
        target.mkdir()
        self.staging.symlink_to(target, target_is_directory=True)
        self.assertNotEqual(self.run_inline(0).returncode, 0)
        self.assertEqual(list(target.iterdir()), [])

    def test_uploads_and_environment(self):
        self.assertIn('staging_dir = "/var/tmp/packer"', self.hcl)
        files = re.findall(r'provisioner "file" \{(.*?)\n  \}', self.hcl, re.S)
        self.assertEqual(len(files), 4)
        for block in files:
            self.assertIn("local.staging_dir", block)
            self.assertNotIn('"/tmp', block)
        shells = re.findall(r'provisioner "shell" \{(.*?)\n  \}', self.hcl, re.S)
        for block in shells:
            self.assertIn('remote_folder = "/var/tmp"', re.sub(r" +", " ", block))
            if "script " in block:
                self.assertIn('"STAGING_DIR=${local.staging_dir}"', block)
        self.assertLess(self.hcl.index(self.inline[0]), self.hcl.index('provisioner "file"'))
        self.assertGreater(self.hcl.index(self.inline[-1]), self.hcl.index('script           = "../shared/scripts/cleanup.sh"'))

    def test_base_consumers_use_staged_files(self):
        self.stage()
        for script in (BASE / "scripts").glob("install-*.sh"):
            text = script.read_text()
            self.assertNotRegex(text, r"/tmp/(conf|versions|distro)")
            # Execute the real source preamble, without installing anything.
            sources = list(re.finditer(r'^source .*$', text, re.M))
            self.assertTrue(sources, script)
            preamble = text[:sources[-1].end()]
            result = subprocess.run(["bash", "-c", preamble], env={**os.environ, "STAGING_DIR": str(self.staging)}, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            # Expand every real config source glob against the uploaded tree.
            paths = re.findall(r'sudo cp ("\$\{STAGING_DIR\}/conf/[^"\n]+"\*?)', text)
            for path in paths:
                command = 'for file in ' + path + '; do test -f "$file" || exit 1; done'
                subprocess.run(["bash", "-eu", "-c", command], env={**os.environ, "STAGING_DIR": str(self.staging)}, check=True)

    def test_shared_cleanup_preserves_stack_default(self):
        text = (SHARED / "scripts/cleanup.sh").read_text()
        self.assertIn('source "${STAGING_DIR:-/tmp}/distro.sh"', text)
        # Exercise the unset-environment branch without touching host /tmp.
        env = {key: value for key, value in os.environ.items() if key != "STAGING_DIR"}
        command = 'source() { printf "%s" "$1"; }; pkg_clean() { :; }; export -f source pkg_clean; bash "$1"'
        result = subprocess.run(["bash", "-c", command, "--", str(SHARED / "scripts/cleanup.sh")], env=env, capture_output=True, check=True)
        self.assertEqual(result.stdout.decode(), "/tmp/distro.sh")
        self.stage()
        for distro, expected in [("amazonlinux2023", "dnf clean all"), ("ubuntu2404", "apt-get clean")]:
            # Bash function mocks sudo; no root access, network or package changes.
            command = 'sudo() { printf "%s\\n" "$*"; }; export -f sudo; bash "$1"'
            result = subprocess.run(["bash", "-c", command, "--", str(SHARED / "scripts/cleanup.sh")], env={**os.environ, "STAGING_DIR": str(self.staging), "OS_DISTRO": distro}, capture_output=True, check=True)
            self.assertEqual(result.stdout.decode().strip(), expected)


if __name__ == "__main__":
    unittest.main()
