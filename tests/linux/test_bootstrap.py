"""Run the Linux installer with disposable paths and simulated AWS/services.

Actual cloud-init, systemd, and ASG replacement are sandbox integration checks.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[2]
INSTALLER = ROOT / "packer/linux/stack/conf/bin/bk-install-elastic-stack.sh"

COMMANDS = r'''
set -Eeuo pipefail
curl() {
  [[ "${METADATA_FAILS:-false}" != true ]] || return 28
  case "${*: -1}" in
    */api/token) echo token ;;
    */instance-identity/document)
      echo '{"instanceId":"i-test","pendingTime":"1970-01-01T00:16:40Z"}' ;;
    */instance-id) echo i-test ;;
    *) return 99 ;;
  esac
}
date() {
  if [[ "$*" == *' -d '* ]]; then echo 1000; else cat "$TEST_STATE/now"; fi
}
sleep() { echo $(( $(cat "$TEST_STATE/now") + $1 )) > "$TEST_STATE/now"; }
aws() { python3 "$TEST_STATE/aws.py" "$@"; }
cfn-signal() { python3 "$TEST_STATE/aws.py" signal "$@"; }
docker() { echo 'Docker version 25.0.0, build test'; }
chown() { :; }
su() { :; }
getent() { echo 'ec2-user:x:1000:1000::/home/ec2-user:/bin/bash'; }
logger() { cat; }
systemctl() {
  if [[ "$*" == 'enable --now buildkite-agent' ]]; then
    [[ "${SERVICE_FAILS:-false}" != true ]] || return 7
    touch "$TEST_STATE/running"
    if [[ "${MARKER_FAILS:-false}" == true ]]; then
      rm "$TEST_STATE/var/log/elastic-stack-bootstrap-status"
      mkdir "$TEST_STATE/var/log/elastic-stack-bootstrap-status"
    fi
  fi
}
source "$1"
'''

# Model the external lifecycle, not the installer's helpers. A successful
# completion can change AWS state even when its response is lost.
AWS = r'''
import json, os, pathlib, sys
p = pathlib.Path(os.environ['TEST_STATE'])
args = sys.argv[1:]
state = json.loads((p / 'aws.json').read_text())
command = args[0] if args[0] == 'signal' else args[1]
def save():
    (p / 'aws.json').write_text(json.dumps(state))
def error(message):
    print(message, file=sys.stderr)
    save()
    sys.exit(1)
if command == 'get-parameter':
    print('test-token')
elif command == 'describe-auto-scaling-instances':
    if state.get('describe_denied'):
        error('AccessDenied: describe denied')
    if state.get('completion_at'):
        now = int((p / 'now').read_text())
        if now >= state['completion_at'] + 10 and not state.get('stuck'):
            state['lifecycle'] = 'InService'
        elif now >= state['completion_at'] + 2:
            state['lifecycle'] = 'Pending:Proceed'
    print(json.dumps({'AutoScalingInstances': [] if state['lifecycle'] == 'absent' else [
        {'AutoScalingGroupName': 'test-asg', 'LifecycleState': state['lifecycle']}]}))
elif command == 'complete-lifecycle-action':
    result = args[args.index('--lifecycle-action-result') + 1]
    if result == 'CONTINUE':
        marker = p / 'var/log/elastic-stack-bootstrap-status'
        if not (p / 'running').exists() or marker.read_text().strip() != 'Completed':
            error('Invalid completion: configuration and service startup required')
        if state.get('denied'):
            error('AccessDenied: completion denied')
        if state.get('throttle'):
            error('Throttling: try again')
        if state.get('transient'):
            state['transient'] = False
            error('Connection timed out')
        if state.get('delayed_lost_response'):
            if state.get('completion_at'):
                error('ValidationError: No active Lifecycle Action found')
            state['completion_at'] = int((p / 'now').read_text()) + 1
            error('RequestTimeout: completion response lost')
        if state.get('no_action'):
            error('ValidationError: No active Lifecycle Action found')
        state['lifecycle'] = 'InService'
        if state.get('lost_response'):
            state['lost_response'] = False
            error('Connection closed after accepting CONTINUE')
    else:
        state['abandoned_at'] = int((p / 'now').read_text())
        state['lifecycle'] = 'Terminating:Wait'
elif command == 'set-instance-health':
    state['unhealthy'] = True
elif command == 'signal':
    state.setdefault('signals', []).append({
        'code': args[args.index('--exit-code') + 1],
        'lifecycle': state['lifecycle'],
        'marker': (p / 'var/log/elastic-stack-bootstrap-status').read_text().strip(),
    })
    if state.get('signal_fails'):
        error('CloudFormation endpoint unavailable')
else:
    error('Unexpected command: ' + repr(args))
save()
'''


class BootstrapTest(unittest.TestCase):
    def run_bootstrap(self, *, marker=None, hook=True, customer_fails=False,
                      service_fails=False, marker_fails=False, metadata_fails=False,
                      expired=False, **aws_state):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            for path in ("etc/buildkite-agent", "var/lib/buildkite-agent", "var/log", "usr/bin",
                         "usr/local/bin", "tmp"):
                (work / path).mkdir(parents=True)
            status = work / "var/log/elastic-stack-bootstrap-status"
            if marker is not None:
                status.write_text(marker)
            # Sentinel protects Completed re-entry from configuration changes.
            config = work / "etc/buildkite-agent/buildkite-agent.cfg"
            config.write_text("existing configuration")
            if marker == "Completed":
                (work / "running").touch()
            (work / "aws.py").write_text(AWS)
            state = {"lifecycle": "Pending:Wait", "signals": [], **aws_state}
            (work / "aws.json").write_text(json.dumps(state))
            (work / "now").write_text("1901" if expired else "1030")
            source = re.sub(r"/(?:etc|var|usr|mnt|opt|tmp)/",
                            lambda match: str(work) + match[0], INSTALLER.read_text())
            source = source.replace("/dev/console", str(work / "console"))
            script = work / "installer.sh"
            script.write_text(source)
            fetch = work / "usr/local/bin/bk-fetch.sh"
            fetch.write_text('#!/bin/bash\nprintf "exit 7\\n" > "$2"\n')
            fetch.chmod(0o755)
            env = dict(os.environ, TEST_STATE=str(work))
            for key in """
                BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS BUILDKITE_AGENTS_PER_INSTANCE
                BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME BUILDKITE_AGENT_EXPERIMENTS
                BUILDKITE_AGENT_JOB_VERIFICATION_NO_SIGNATURE_BEHAVIOR
                BUILDKITE_AGENT_SIGNING_KEY_ID BUILDKITE_AGENT_SIGNING_KEY_PATH
                BUILDKITE_AGENT_SIGNING_KMS_KEY BUILDKITE_AGENT_TOKEN_PATH
                BUILDKITE_AGENT_VERIFICATION_KEY_PATH BUILDKITE_ARTIFACTS_BUCKET
                BUILDKITE_AUTHORIZED_USERS_URL BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT
                BUILDKITE_ENV_FILE_URL BUILDKITE_PURGE_BUILDS_ON_DISK_FULL
                BUILDKITE_QUEUE BUILDKITE_SCALE_IN_IDLE_PERIOD BUILDKITE_SECRETS_BUCKET
                BUILDKITE_SECRETS_BUCKET_REGION BUILDKITE_STACK_VERSION
                BUILDKITE_S3_ACL BUILDKITE_S3_DEFAULT_REGION
                BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL
                DOCKER_BUILDER_PRUNE_ENABLED DOCKER_EXPERIMENTAL DOCKER_PRUNE_UNTIL
                DOCKER_USERNS_REMAP ECR_CREDENTIAL_HELPER_ENABLED ENABLE_PRE_EXIT_DISK_CLEANUP
            """.split():
                env[key] = ""
            env.update(AWS_REGION="us-east-1", BUILDKITE_AGENT_RELEASE="stable",
                       BUILDKITE_STACK_NAME="test", BUILDKITE_STACK_DEPLOYED_BY="cloudformation",
                       SECRETS_PLUGIN_ENABLED="false", ECR_PLUGIN_ENABLED="false",
                       DOCKER_LOGIN_PLUGIN_ENABLED="false", ENABLE_RESOURCE_LIMITS="false",
                       ENABLE_EC2_LOG_RETENTION_POLICY="false",
                       BUILDKITE_LAUNCH_HOOK_NAME="buildkite-agent-launch" if hook else "",
                       BUILDKITE_LAUNCH_TIMEOUT="900",
                       SERVICE_FAILS=str(service_fails).lower(), MARKER_FAILS=str(marker_fails).lower(),
                       METADATA_FAILS=str(metadata_fails).lower())
            if customer_fails:
                env['BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT'] = 'https://example.com/bootstrap'
            result = subprocess.run(["bash", "-c", COMMANDS, "test", str(script)],
                                    env=env, capture_output=True, text=True, timeout=15)
            return (result, json.loads((work / "aws.json").read_text()),
                    status.read_text().strip() if status.is_file() else None,
                    (work / "running").exists(), config.read_text(),
                    int((work / "now").read_text()))

    def test_success_acknowledges_completed_configuration(self):
        result, state, marker, running, _, _ = self.run_bootstrap()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(running)
        self.assertEqual(marker, "Completed")
        self.assertEqual(state['lifecycle'], 'InService')
        self.assertEqual(state['signals'], [
            {'code': '0', 'lifecycle': 'InService', 'marker': 'Completed'}])

    def test_configuration_failure_abandons_without_failing_deployment(self):
        result, state, marker, running, _, _ = self.run_bootstrap(customer_fails=True)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertFalse(running)
        self.assertEqual(marker, 'Started')
        self.assertEqual(state['lifecycle'], 'Terminating:Wait')
        self.assertEqual(state['signals'], [])
        self.assertGreaterEqual(state['abandoned_at'], 1040,
                                'Allow log collection before ABANDON can terminate the instance')

    def test_post_start_failures_do_not_fail_cloud_final(self):
        for failure in ({'denied': True}, {'marker_fails': True}, {'signal_fails': True}):
            with self.subTest(failure=failure):
                result, state, _, running, _, _ = self.run_bootstrap(**failure)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(running)
                self.assertFalse(state.get('unhealthy', False))
                self.assertNotEqual(state['lifecycle'], 'Terminating:Wait')
                if not failure.get('signal_fails'):
                    self.assertEqual(state['signals'], [])

    def test_service_start_failure_is_still_a_bootstrap_failure(self):
        result, state, marker, running, _, _ = self.run_bootstrap(service_fails=True)
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertFalse(running)
        self.assertEqual(marker, 'Started')
        self.assertEqual(state['lifecycle'], 'Terminating:Wait')
        self.assertEqual(state['signals'], [])

    def test_completed_reentry_preserves_configuration_and_reconciles(self):
        for lifecycle in ('Pending:Wait', 'InService'):
            with self.subTest(lifecycle=lifecycle):
                result, state, marker, _, config, _ = self.run_bootstrap(
                    marker='Completed', lifecycle=lifecycle, customer_fails=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(config, 'existing configuration')
                self.assertEqual(marker, 'Completed')
                self.assertEqual(state['lifecycle'], 'InService')
                self.assertEqual(len(state['signals']), 1)

    def test_incomplete_reentry_rejects_reconfiguration(self):
        for marker in ('Started', 'invalid', ''):
            with self.subTest(marker=marker):
                result, state, actual, running, config, _ = self.run_bootstrap(marker=marker)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(running)
                self.assertEqual(config, 'existing configuration')
                self.assertEqual(actual, marker)
                self.assertEqual(state['lifecycle'], 'Terminating:Wait')
                self.assertEqual(state['signals'], [])

    def test_metadata_failure_respects_configuration_boundary(self):
        for completed in (False, True):
            with self.subTest(completed=completed):
                result, state, _, running, config, now = self.run_bootstrap(
                    marker='Completed' if completed else None, metadata_fails=True)
                self.assertEqual(result.returncode, 0 if completed else 1)
                self.assertEqual(running, completed)
                self.assertEqual(config, 'existing configuration')
                self.assertEqual(state['signals'], [])
                deadline = 1060 if completed else 1070
                self.assertLessEqual(now, deadline,
                                     'Metadata retries plus the pre-start logging grace must remain bounded')

    def test_transient_and_lost_completion_responses_recover(self):
        for fault in ('transient', 'lost_response'):
            with self.subTest(fault=fault):
                result, state, marker, running, _, now = self.run_bootstrap(**{fault: True})
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(marker, 'Completed')
                self.assertTrue(running)
                self.assertEqual(state['lifecycle'], 'InService')
                self.assertEqual(state['signals'][0]['code'], '0')
                self.assertLess(now, 1040)

    def test_lost_response_waits_for_delayed_in_service_within_deadline(self):
        for stuck in (False, True):
            with self.subTest(stuck=stuck):
                result, state, marker, running, _, now = self.run_bootstrap(
                    delayed_lost_response=True, stuck=stuck)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(running)
                self.assertEqual(marker, 'Completed')
                self.assertFalse(state.get('unhealthy', False))
                if stuck:
                    self.assertEqual(state['lifecycle'], 'Pending:Proceed')
                    self.assertEqual(state['signals'], [])
                    self.assertGreater(now, 1800)
                    self.assertLess(now, 1900)
                else:
                    self.assertEqual(state['lifecycle'], 'InService')
                    self.assertEqual(state['signals'], [
                        {'code': '0', 'lifecycle': 'InService', 'marker': 'Completed'}])

    def test_unconfirmed_launch_never_signals_success(self):
        cases = ({'no_action': True}, {'denied': True}, {'describe_denied': True},
                 {'throttle': True}, {'expired': True}, {'lifecycle': 'Terminating:Wait'},
                 {'lifecycle': 'absent'})
        for fault in cases:
            with self.subTest(fault=fault):
                result, state, marker, running, _, now = self.run_bootstrap(**fault)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertTrue(running)
                self.assertEqual(marker, 'Completed')
                self.assertEqual(state['signals'], [])
                self.assertFalse(state.get('unhealthy', False))
                if fault.get('throttle') or fault.get('no_action'):
                    self.assertGreater(now, 1800)
                    self.assertLess(now, 1900)
                elif not fault.get('expired'):
                    self.assertLess(now, 1040)

    def test_pre_start_failure_only_marks_in_service_instance_unhealthy(self):
        for lifecycle in ('InService', 'Terminating:Wait', 'absent'):
            with self.subTest(lifecycle=lifecycle):
                result, state, _, running, _, _ = self.run_bootstrap(
                    customer_fails=True, lifecycle=lifecycle)
                self.assertEqual(result.returncode, 7)
                self.assertFalse(running)
                self.assertEqual(state.get('unhealthy', False), lifecycle == 'InService')
                self.assertEqual(state['signals'], [])

    def test_no_hook_preserves_legacy_success_and_failure_signaling(self):
        for fails in (False, True):
            with self.subTest(fails=fails):
                result, state, marker, running, _, _ = self.run_bootstrap(
                    hook=False, customer_fails=fails)
                self.assertEqual(result.returncode, 7 if fails else 0)
                self.assertEqual(running, not fails)
                self.assertEqual(marker, 'Started' if fails else 'Completed')
                self.assertEqual(state['lifecycle'], 'Pending:Wait')
                self.assertEqual(state.get('unhealthy', False), fails)
                self.assertEqual(state['signals'][0]['code'], '7' if fails else '0')

    def test_user_data_stops_at_failed_prerequisite(self):
        template = (ROOT / 'templates/aws-stack.yml').read_text()
        mime = re.search(r'(?ms)^ +Content-Type: multipart/mixed;.*?^ +--==BOUNDARY==--',
                         template).group()
        mime = textwrap.dedent(mime)
        scripts = re.findall(r'(?ms)^Content-Type: text/x-shellscript[^\n]*\n(.*?)(?=^--==BOUNDARY==)',
                             mime)
        self.assertTrue(scripts)
        for failed, expected in (('', ['storage', 'docker', 'installer']),
                                 ('storage', ['storage']), ('docker', ['storage', 'docker'])):
            with self.subTest(failed=failed), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                trace = work / 'trace'
                for name, command in (('storage', 'bk-mount-instance-storage.sh'),
                                      ('docker', 'bk-configure-docker.sh'),
                                      ('installer', 'bk-install-elastic-stack.sh')):
                    path = work / command
                    path.write_text(f'#!/bin/bash\necho {name} >> "{trace}"\n'
                                    f'exit {7 if name == failed else 0}\n')
                    path.chmod(0o755)
                # cloud-init runs every MIME shell part even if an earlier part
                # fails. The fail-fast contract must live inside one shell part.
                for script in scripts:
                    script = re.sub(r'\$\{[^}]+\}', 'test', script)
                    script = script.replace('/usr/local/bin/', str(work) + '/')
                    subprocess.run(['bash', '-c', script], check=False,
                                   capture_output=True, text=True)
                self.assertEqual(trace.read_text().splitlines(), expected)


if __name__ == '__main__':
    unittest.main()
