"""Exercise CloudFormation helper arguments without making AWS requests."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CloudFormationHelpersTest(unittest.TestCase):
    def test_template_and_parameter_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            checkout = Path(directory) / "checkout with spaces"
            checkout.mkdir()
            shutil.copy(ROOT / "Makefile", checkout / "Makefile")
            (checkout / "config.json").write_text("[]")
            binary = Path(directory) / "bin"
            binary.mkdir()
            aws = binary / "aws"
            aws.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['AWS_ARGUMENTS'], 'w') as output:\n"
                "    json.dump(sys.argv[1:], output)\n"
            )
            aws.chmod(0o755)
            # Satisfy macOS tool discovery; template generation is excluded below.
            (binary / "gsed").symlink_to(shutil.which("sed"))
            output = Path(directory) / "arguments.json"
            env = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}",
                       AWS_ARGUMENTS=str(output), PWD=str(checkout))
            for target in ("create-stack", "update-stack"):
                for url in (
                    "https://example.com/template.yml",
                    "https://example.com/template.yml?X-Amz-Date=20261027&X-Amz-Signature=abc",
                    None,
                ):
                    with self.subTest(target=target, url=url):
                        command = ["make", target, "STACK_NAME=test", "VERSION=test"]
                        if url:
                            command.append(f"TEMPLATE_URL={url}")
                        else:
                            command += ["-o", "build/aws-stack.yml"]
                        result = subprocess.run(command, cwd=checkout, env=env,
                                                capture_output=True, text=True)
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        arguments = json.loads(output.read_text())
                        expected = ["cloudformation", target, "--output", "text",
                                    "--stack-name", "test"]
                        if target == "create-stack":
                            expected.append("--disable-rollback")
                        expected += (["--template-url", url] if url else
                                     ["--template-body", f"file://{checkout}/build/aws-stack.yml"])
                        expected += ["--capabilities", "CAPABILITY_IAM", "CAPABILITY_NAMED_IAM",
                                     "CAPABILITY_AUTO_EXPAND", "--parameters",
                                     f"file://{checkout}/config.json"]
                        self.assertEqual(arguments, expected)


if __name__ == "__main__":
    unittest.main()
