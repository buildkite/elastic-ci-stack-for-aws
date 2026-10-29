"""Validate plugin checkouts through the Packer entry point, without AWS calls."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class PluginCheckoutTest(unittest.TestCase):
    def test_checkout_is_validated_before_building(self):
        cases = (
            ("complete", "windows", "stack", True),
            ("untracked", "linux", "stack-cis", True),
            ("missing hook", "windows", "stack", False),
            ("modified hook", "linux", "stack", False),
            ("staged deletion", "windows", "stack", False),
            ("uninitialized", "windows", "stack", False),
            ("wrong commit", "linux", "stack-cis", False),
            ("uninitialized nested", "windows", "stack", False),
            ("missing nested file", "windows", "stack", False),
            ("uninitialized", "windows", "base", True),
            ("uninitialized", "linux", "base-cis", True),
        )
        for fault, os_name, variant, accepted in cases:
            with self.subTest(fault=fault, os=os_name, variant=variant), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull,
                           GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.invalid",
                           GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.invalid",
                           GIT_ALLOW_PROTOCOL="file")

                def git(repo, *arguments):
                    return subprocess.run(["git", *arguments], cwd=repo, env=env,
                                          check=True, capture_output=True, text=True).stdout.strip()

                nested = work / "nested"
                nested.mkdir()
                git(nested, "init", "--quiet")
                (nested / "library.sh").write_text("echo library\n")
                git(nested, "add", ".")
                git(nested, "commit", "--quiet", "-m", "Library fixture")

                source = work / "source"
                source.mkdir()
                git(source, "init", "--quiet")
                (source / "hooks").mkdir()
                (source / "hooks/environment").write_text("echo first\n")
                git(source, "submodule", "add", "--quiet", str(nested), "lib")
                git(source, "add", ".")
                git(source, "commit", "--quiet", "-m", "Plugin fixture")
                (source / "hooks/environment").write_text("echo pinned\n")
                git(source, "commit", "--quiet", "-am", "Pinned fixture")

                checkout = work / "checkout with spaces"
                checkout.mkdir()
                git(checkout, "init", "--quiet")
                git(checkout, "submodule", "add", "--quiet", str(source), "plugins/ecr")
                git(checkout, "commit", "--quiet", "-am", "Stack fixture")
                git(checkout, "submodule", "update", "--init", "--recursive")
                plugin = checkout / "plugins/ecr"
                hook = plugin / "hooks/environment"
                if fault == "untracked":
                    (plugin / "notes.txt").write_text("local notes\n")
                elif fault == "missing hook":
                    hook.unlink()
                elif fault == "modified hook":
                    hook.write_text("echo modified\n")
                elif fault == "staged deletion":
                    git(plugin, "rm", "hooks/environment")
                elif fault == "uninitialized":
                    git(checkout, "submodule", "deinit", "--force", "plugins/ecr")
                elif fault == "wrong commit":
                    git(plugin, "checkout", "--quiet", "HEAD^")
                elif fault == "uninitialized nested":
                    git(plugin, "submodule", "deinit", "--force", "lib")
                elif fault == "missing nested file":
                    (plugin / "lib/library.sh").unlink()

                # Stop at make, before it could invoke Packer; any AWS call is an error.
                binary = work / "bin"
                binary.mkdir()
                for name, body in {
                    "make": 'touch "$BUILD_REACHED"; exit 42',
                    "buildkite-agent": 'touch "$METADATA_REACHED"; echo ami-fixture',
                    "aws": 'echo "Unexpected AWS call" >&2; exit 99',
                }.items():
                    command = binary / name
                    command.write_text(f"#!/bin/sh\n{body}\n")
                    command.chmod(0o755)
                build_reached = work / "build-reached"
                metadata_reached = work / "metadata-reached"
                env.update(PATH=f"{binary}:{os.environ['PATH']}",
                           BUILDKITE_AWS_STACK_BUCKET="fixture",
                           BUILD_REACHED=str(build_reached), METADATA_REACHED=str(metadata_reached))
                before = git(checkout, "submodule", "status", "--recursive")
                result = subprocess.run(
                    ["bash", str(ROOT / ".buildkite/steps/packer.sh"), os_name, "amd64", variant],
                    cwd=checkout, env=env, capture_output=True, text=True,
                )
                self.assertEqual(result.returncode, 42 if accepted else 1,
                                 result.stdout + result.stderr)
                self.assertEqual(build_reached.exists(), accepted)
                if not accepted:
                    self.assertFalse(metadata_reached.exists(), "Validation must precede external calls")
                    self.assertIn("plugins/ecr", result.stdout + result.stderr)
                self.assertEqual(git(checkout, "submodule", "status", "--recursive"), before,
                                 "Preflight must not repair or reset submodules")
                if fault == "missing hook":
                    self.assertFalse(hook.exists(), "Preflight must not restore missing files")


if __name__ == "__main__":
    unittest.main()
