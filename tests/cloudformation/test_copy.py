"""Exercise the CI AMI copy script's mapping cache without calling AWS."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

# Answers the cache download with $CACHED_MAPPING; any call past tagging fails.
STUB = """#!/bin/bash
case "$1 $2" in
"ec2 create-tags") ;;
"s3 cp") mkdir -p "$(dirname "$4")" && printf '%s' "$CACHED_MAPPING" >"$4" ;;
*) echo "Unexpected AWS command: $*" >&2; exit 99 ;;
esac
"""

HEADER = "Mappings:\n  AWSRegion2AMI:\n"
FIVE_IMAGES = ("linuxamd64: ami-1, linuxarm64: ami-2, windows: ami-3, "
               "ubuntu2404amd64: ami-4, ubuntu2404arm64: ami-5")


class CachedMappingTest(unittest.TestCase):
    def copy(self, cached_mapping):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "bin"
            binary.mkdir()
            stub = binary / "aws"
            stub.write_text(STUB)
            stub.chmod(0o755)
            env = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}", AWS_REGION="us-east-1",
                       BUILDKITE_BRANCH="main", BUILDKITE_TAG="",
                       BUILDKITE_AWS_STACK_BUCKET="test-bucket", CACHED_MAPPING=cached_mapping)
            result = subprocess.run(
                ["bash", str(ROOT / ".buildkite/steps/copy.sh"), "ami-linux", "ami-windows", "ami-ubuntu"],
                cwd=directory, env=env, capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return (Path(directory) / "build/mappings.yml").read_text()

    def test_mapping_cached_before_windows2025_gains_an_empty_key_in_every_region(self):
        cached = HEADER + "".join(f"    {region} : {{ {FIVE_IMAGES} }}\n" for region in ("us-east-1", "eu-west-1"))
        self.assertEqual(self.copy(cached), HEADER + "".join(
            f"    {region} : {{ {FIVE_IMAGES}, windows2025: '' }}\n" for region in ("us-east-1", "eu-west-1")))

    def test_cached_mapping_with_windows2025_is_unchanged(self):
        cached = HEADER + (f"    us-east-1 : {{ {FIVE_IMAGES}, windows2025: ami-6 }}\n"
                           f"    eu-west-1 : {{ {FIVE_IMAGES}, windows2025: '' }}\n")
        self.assertEqual(self.copy(cached), cached)


if __name__ == "__main__":
    unittest.main()
