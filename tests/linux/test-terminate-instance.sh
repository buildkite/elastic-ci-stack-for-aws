#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/packer/linux/stack/conf/buildkite-agent/scripts/terminate-instance"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"; rm -f /tmp/buildkite-agent-termination-marker' EXIT

mkdir -p "$TEST_TMP/bin"

cat >"$TEST_TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
case "${*: -1}" in
  */api/token) printf 'mock-token' ;;
  */instance-id) printf 'i-0123456789abcdef0' ;;
  */placement/region) printf 'us-east-1' ;;
  *) exit 1 ;;
esac
EOF

cat >"$TEST_TMP/bin/timeout" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "5" ]] || exit 2
shift
exec "$@"
EOF

cat >"$TEST_TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "show buildkite-agent.service --property=ExecMainStartTimestampMonotonic --property=ExecMainExitTimestampMonotonic" ]] || exit 2

case "${SYSTEMCTL_RESULT:-success}" in
  success)
    printf 'ExecMainStartTimestampMonotonic=%s\n' "${AGENT_START_TIMESTAMP:-1000000}"
    printf 'ExecMainExitTimestampMonotonic=%s\n' "${AGENT_EXIT_TIMESTAMP:-2000000}"
    ;;
  malformed)
    printf 'ExecMainStartTimestampMonotonic=unknown\n'
    printf 'ExecMainExitTimestampMonotonic=%s\n' "${AGENT_EXIT_TIMESTAMP:-2000000}"
    ;;
  failure)
    exit 1
    ;;
esac
EOF

cat >"$TEST_TMP/bin/aws" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$AWS_CALL_LOG"

if [[ "$*" == *"--should-decrement-desired-capacity"* ]]; then
  case "${AWS_DECREMENT_RESULT:-success}" in
    success)
      printf '{"Activity":{"StatusCode":"InProgress"}}\n'
      ;;
    min-size)
      cat >&2 <<'ERROR'
An error occurred (ValidationError) when calling the TerminateInstanceInAutoScalingGroup operation: Currently, desiredSize equals minSize. Terminating instance without replacement will violate group's min size constraint. Either set shouldDecrementDesiredCapacity flag to false or lower group's min size.
ERROR
      exit 254
      ;;
    other-validation)
      echo 'An error occurred (ValidationError) when calling the TerminateInstanceInAutoScalingGroup operation: Another validation constraint failed.' >&2
      exit 254
      ;;
    throttled)
      echo 'An error occurred (Throttling) when calling the TerminateInstanceInAutoScalingGroup operation: Rate exceeded' >&2
      exit 254
      ;;
  esac
elif [[ "$*" == *"--no-should-decrement-desired-capacity"* ]]; then
  [[ "${AWS_NO_DECREMENT_RESULT:-success}" == "success" ]] || exit 254
elif [[ "$*" == *"set-instance-health"* ]]; then
  [[ "${AWS_HEALTH_RESULT:-success}" == "success" ]] || exit 254
else
  echo "Unexpected aws call: $*" >&2
  exit 2
fi
EOF

chmod +x "$TEST_TMP/bin/"*
export PATH="$TEST_TMP/bin:$PATH"
export AWS_CALL_LOG="$TEST_TMP/aws-calls"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_status() {
  local expected=$1
  [[ $status -eq $expected ]] || fail "expected status $expected, got $status; output: $output"
}

assert_output_contains() {
  local expected=$1
  [[ $output == *"$expected"* ]] || fail "output did not contain '$expected': $output"
}

assert_calls() {
  local expected=$1
  local actual
  actual=$(wc -l <"$AWS_CALL_LOG" | tr -d ' ')
  [[ $actual -eq $expected ]] || fail "expected $expected AWS calls, got $actual: $(cat "$AWS_CALL_LOG")"
}

assert_call_contains() {
  local line=$1
  local expected=$2
  local actual
  actual=$(sed -n "${line}p" "$AWS_CALL_LOG")
  [[ $actual == *"$expected"* ]] || fail "AWS call $line did not contain '$expected': $actual"
}

run_case() {
  : >"$AWS_CALL_LOG"
  rm -f /tmp/buildkite-agent-termination-marker
  set +e
  output=$(env -i PATH="$PATH" AWS_CALL_LOG="$AWS_CALL_LOG" "$@" "$SCRIPT" 2>&1)
  status=$?
  set -e
}

run_scaler_drain_case() {
  : >"$AWS_CALL_LOG"
  touch /tmp/buildkite-agent-termination-marker
  set +e
  output=$(env -i PATH="$PATH" AWS_CALL_LOG="$AWS_CALL_LOG" "$@" "$SCRIPT" 2>&1)
  status=$?
  set -e
}

INSTALLER="$ROOT/packer/linux/stack/conf/bin/bk-install-elastic-stack.sh"
# These are literal installer templates; variable expansion here would invalidate the check.
# shellcheck disable=SC2016
grep -Fq 'set_always         "BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME" "$BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME"' "$INSTALLER" \
  || fail "installer does not expose the uptime limit in cfn-env"
# shellcheck disable=SC2016
grep -Fq 'Environment="BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=${BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME}"' "$INSTALLER" \
  || fail "installer does not expose the uptime limit to the systemd service"

echo "Normal scale-in decrements desired capacity"
run_case AWS_DECREMENT_RESULT=success BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success
assert_status 0
assert_calls 1
assert_call_contains 1 --should-decrement-desired-capacity

echo "Terminate-after-job decrements desired capacity when possible"
run_case AWS_DECREMENT_RESULT=success BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=true SERVICE_RESULT=success
assert_status 0
assert_calls 1
assert_call_contains 1 --should-decrement-desired-capacity

# Uptime is disabled, so these cases must not consult systemd timestamps.
echo "Idle instance at MinSize is retained for systemd to restart the agent"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=0 SYSTEMCTL_RESULT=failure
assert_status 1
assert_output_contains "Auto Scaling group is at MinSize"
assert_calls 1
assert_call_contains 1 --should-decrement-desired-capacity

echo "Unset terminate-after-job and uptime flags retain a cleanly exited instance at MinSize"
run_case AWS_DECREMENT_RESULT=min-size SERVICE_RESULT=success SYSTEMCTL_RESULT=failure
assert_status 1
assert_calls 1

echo "A zero-padded disabled uptime retains a cleanly exited instance at MinSize"
run_case AWS_DECREMENT_RESULT=min-size SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=00 SYSTEMCTL_RESULT=failure
assert_status 1
assert_calls 1

echo "An agent below its maximum uptime is retained at MinSize"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 AGENT_START_TIMESTAMP=1000000 AGENT_EXIT_TIMESTAMP=60999999
assert_status 1
assert_calls 1

echo "A scaler-requested drain is replaced at MinSize"
run_scaler_drain_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=0
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "A zero-padded uptime is treated as decimal"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=060 AGENT_START_TIMESTAMP=1000000 AGENT_EXIT_TIMESTAMP=60999999
assert_status 1
assert_calls 1

echo "An agent at its maximum uptime is replaced at MinSize"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 AGENT_START_TIMESTAMP=1000000 AGENT_EXIT_TIMESTAMP=61000000
assert_status 0
assert_output_contains "Agent reached its maximum uptime"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Unavailable agent timestamps fail safe to replacement"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 SYSTEMCTL_RESULT=failure
assert_status 0
assert_output_contains "Could not read agent process timestamps"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Malformed agent timestamps fail safe to replacement"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 SYSTEMCTL_RESULT=malformed
assert_status 0
assert_output_contains "Could not determine agent process uptime"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Zero agent timestamps fail safe to replacement"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 AGENT_START_TIMESTAMP=0 AGENT_EXIT_TIMESTAMP=0
assert_status 0
assert_output_contains "Could not determine agent process uptime"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Out-of-order agent timestamps fail safe to replacement"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=60 AGENT_START_TIMESTAMP=2000000 AGENT_EXIT_TIMESTAMP=1000000
assert_status 0
assert_output_contains "Could not determine agent process uptime"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "An invalid maximum uptime fails safe to replacement"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success \
  BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME=invalid
assert_status 0
assert_output_contains "Invalid agent uptime limit"
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Terminate-after-job replaces an instance at MinSize"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=true SERVICE_RESULT=success
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "An unknown service result fails safe by replacing the instance at MinSize"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "A failed agent is replaced at MinSize"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=exit-code
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "A partial MinSize error match retains the replacement fallback"
run_case AWS_DECREMENT_RESULT=other-validation BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Unrelated termination failures retain the replacement fallback"
run_case AWS_DECREMENT_RESULT=throttled BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success
assert_status 0
assert_calls 2
assert_call_contains 2 --no-should-decrement-desired-capacity

echo "Failed direct replacement marks the instance unhealthy"
run_case AWS_DECREMENT_RESULT=throttled AWS_NO_DECREMENT_RESULT=failure BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success
assert_status 0
assert_calls 3
assert_call_contains 3 set-instance-health

echo "All terminate-instance tests passed"
