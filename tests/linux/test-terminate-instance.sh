#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/packer/linux/stack/conf/buildkite-agent/scripts/terminate-instance"
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

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
  set +e
  output=$(env -i PATH="$PATH" AWS_CALL_LOG="$AWS_CALL_LOG" "$@" "$SCRIPT" 2>&1)
  status=$?
  set -e
}

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

echo "Idle instance at MinSize is retained for systemd to restart the agent"
run_case AWS_DECREMENT_RESULT=min-size BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=false SERVICE_RESULT=success
assert_status 1
assert_output_contains "Auto Scaling group is at MinSize"
assert_calls 1
assert_call_contains 1 --should-decrement-desired-capacity

echo "Unset terminate-after-job flag retains a cleanly exited instance at MinSize"
run_case AWS_DECREMENT_RESULT=min-size SERVICE_RESULT=success
assert_status 1
assert_calls 1

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
