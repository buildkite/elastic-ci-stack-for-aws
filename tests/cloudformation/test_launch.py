"""Exercise the CI launch script without creating AWS resources."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

STUB = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

command = Path(sys.argv[0]).name
args = [arg for arg in sys.argv[1:] if arg != '--no-cli-pager']
if command == 'make':
    sys.exit(0)
if command == 'buildkite-agent':
    print('arn:aws:iam::123456789012:role/test' if args[-1] == 'service-role-arn' else 'ami-test')
    sys.exit(0)
if command != 'aws':
    sys.exit('Unexpected external command: ' + command)

if args[:2] == ['ec2', 'describe-vpcs']:
    print('vpc-test')
elif args[:2] == ['ec2', 'describe-subnets']:
    print('subnet-test us-east-1a')
elif args[:2] in [['s3', 'cp'], ['cloudformation', 'validate-template']]:
    pass
elif args[:2] == ['cloudformation', 'create-stack']:
    print('arn:aws:cloudformation:us-east-1:123456789012:stack/test/id')
elif args[:2] in [
    ['cloudformation', 'wait'],
    ['cloudformation', 'describe-stack-events'],
    ['cloudformation', 'list-stack-resources'],
]:
    assert args[args.index('--stack-name') + 1] == os.environ['EXPECTED_STACK']
    if args[1] == 'wait':
        assert args[2] == 'stack-create-complete'
        if os.environ.get('WAITER_ERROR'):
            print(os.environ['WAITER_ERROR'], file=sys.stderr)
            sys.exit(255)
    else:
        assert '--no-paginate' not in args and '--max-items' not in args
        if args[1] == 'describe-stack-events':
            assert args[args.index('--output') + 1] == 'json'
            if os.environ.get('DIAGNOSTICS_FAIL'):
                sys.exit('Unable to retrieve stack events')
            print(os.environ['STACK_EVENTS'])
        else:
            if os.environ.get('INVENTORY_FAIL'):
                sys.exit('Unable to retrieve stack resources')
            if args[args.index('--output') + 1] == 'table':
                assert args[args.index('--query') + 1] == 'StackResourceSummaries[].{KEY:LogicalResourceId,TYPE:ResourceType}'
                print('| KEY | TYPE |')
                for resource in json.loads(os.environ['STACK_RESOURCES'])['StackResourceSummaries']:
                    print('| ' + resource['LogicalResourceId'] + ' | ' + resource['ResourceType'] + ' |')
            else:
                print(os.environ['STACK_RESOURCES'])
else:
    sys.exit('Unexpected AWS command: ' + str(args))
"""


class StackLaunchTest(unittest.TestCase):
    def launch(self, **overrides):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / "bin"
            binary.mkdir()
            for command in ("aws", "buildkite-agent", "make", "wget"):
                stub = binary / command
                stub.write_text(STUB)
                stub.chmod(0o755)
            env = dict(os.environ, PATH=f"{binary}:{os.environ['PATH']}",
                       BUILDKITE_BUILD_NUMBER="42", BUILDKITE_COMMIT="test-commit",
                       BUILDKITE_AWS_STACK_AGENT_TOKEN="test-token",
                       EXPECTED_STACK="buildkite-aws-stack-test-linux-amd64-42",
                       STACK_RESOURCES=json.dumps(self.resources),
                       STACK_EVENTS=json.dumps(self.events), **overrides)
            return subprocess.run(
                ["bash", str(ROOT / ".buildkite/steps/launch.sh")],
                cwd=directory, env=env, capture_output=True, text=True,
            )

    def setUp(self):
        self.resources = {"StackResourceSummaries": [
            {"LogicalResourceId": "SecurityGroup", "PhysicalResourceId": "sg-test",
             "ResourceType": "AWS::EC2::SecurityGroup"},
            {"LogicalResourceId": "AgentLaunchTemplate", "PhysicalResourceId": "lt-test",
             "ResourceType": "AWS::EC2::LaunchTemplate"},
        ]}
        self.events = {"StackEvents": [
            {"LogicalResourceId": "AgentLaunchTemplate", "ResourceStatus": "CREATE_FAILED",
             "ResourceStatusReason": "Instance type is unavailable"}
        ]}

    def test_success_prints_every_resource_as_key_type_rows(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        rows = [tuple(column.strip() for column in line.split("|")[1:-1])
                for line in result.stdout.splitlines() if line.startswith("|")]
        self.assertEqual(rows, [
            ("KEY", "TYPE"),
            ("SecurityGroup", "AWS::EC2::SecurityGroup"),
            ("AgentLaunchTemplate", "AWS::EC2::LaunchTemplate"),
        ])

    def test_waiter_failure_or_timeout_prints_events_and_fails(self):
        for reason in ("Stack reached CREATE_FAILED", "Max attempts exceeded"):
            with self.subTest(reason=reason):
                result = self.launch(WAITER_ERROR=reason)
                self.assertEqual(result.returncode, 255, result.stdout + result.stderr)
                self.assertIn(reason, result.stderr)
                self.assertEqual(json.loads(result.stdout[result.stdout.index("{"):]), self.events)

    def test_diagnostics_failure_preserves_waiter_failure(self):
        result = self.launch(WAITER_ERROR="Stack reached CREATE_FAILED", DIAGNOSTICS_FAIL="1")
        self.assertEqual(result.returncode, 255, result.stdout + result.stderr)
        self.assertIn("Unable to retrieve stack events", result.stderr)

    def test_inventory_failure_fails_the_launch(self):
        result = self.launch(INVENTORY_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Unable to retrieve stack resources", result.stderr)


if __name__ == "__main__":
    unittest.main()
