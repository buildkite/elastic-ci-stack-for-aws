#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/packer/linux/stack/conf/buildkite-agent/scripts/stop-agent-gracefully"
TEST_TMP=$(mktemp -d)
MARKER="$TEST_TMP/termination-marker"
trap 'rm -rf "$TEST_TMP"' EXIT

mkdir -p "$TEST_TMP/bin" "$TEST_TMP/state"

cat >"$TEST_TMP/bin/cat" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "/var/lib/buildkite-agent/cfn-env" ]] || exit 2
printf 'BUILDKITE_AGENTS_PER_INSTANCE=1\n'
EOF

cat >"$TEST_TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
[[ -f "$MARKER" ]] || {
  echo "termination marker was not created before systemctl: $*" >&2
  exit 2
}
printf '%s\n' "$*" >>"$SYSTEMCTL_CALL_LOG"
EOF

cat >"$TEST_TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "+%s -d 2030-01-01T00:00:00Z" ]]; then
  printf '1893456000\n'
elif [[ "$*" == "+%s" ]]; then
  printf '1893455900\n'
else
  exit 2
fi
EOF

cat >"$TEST_TMP/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

cat >"$TEST_TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

chmod +x "$TEST_TMP/bin/"*

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

SYSTEMCTL_CALL_LOG="$TEST_TMP/state/systemctl-calls"
export MARKER SYSTEMCTL_CALL_LOG
rm -f "$MARKER"
: >"$SYSTEMCTL_CALL_LOG"

output=$(env -i \
  PATH="$TEST_TMP/bin:$PATH" \
  MARKER="$MARKER" \
  SYSTEMCTL_CALL_LOG="$SYSTEMCTL_CALL_LOG" \
  BUILDKITE_AGENT_TERMINATION_MARKER_PATH="$MARKER" \
  "$SCRIPT" ec2:SPOT_INSTANCE_TERMINATION unused 2030-01-01T00:00:00Z 2>&1) \
  || fail "Spot interruption handler failed: $output"

[[ -f "$MARKER" ]] || fail "Spot interruption handler did not create the termination marker"
[[ $(wc -l <"$SYSTEMCTL_CALL_LOG" | tr -d ' ') -eq 1 ]] \
  || fail "expected one systemctl call: $(cat "$SYSTEMCTL_CALL_LOG")"
[[ $(cat "$SYSTEMCTL_CALL_LOG") == "kill --kill-who=main --signal=SIGTERM buildkite-agent" ]] \
  || fail "unexpected systemctl call: $(cat "$SYSTEMCTL_CALL_LOG")"
[[ $output == *"All buildkite agents have stopped gracefully"* ]] \
  || fail "unexpected output: $output"

echo "Spot interruption marks the instance for replacement before stopping the agent"

rm -f "$MARKER"
: >"$SYSTEMCTL_CALL_LOG"

output=$(env -i \
  PATH="$TEST_TMP/bin:$PATH" \
  MARKER="$MARKER" \
  SYSTEMCTL_CALL_LOG="$SYSTEMCTL_CALL_LOG" \
  BUILDKITE_AGENT_TERMINATION_MARKER_PATH="$MARKER" \
  "$SCRIPT" autoscaling:EC2_INSTANCE_TERMINATING 2>&1) \
  || fail "Auto Scaling lifecycle handler failed: $output"

[[ -f "$MARKER" ]] || fail "Auto Scaling lifecycle handler did not create the termination marker"
[[ $(wc -l <"$SYSTEMCTL_CALL_LOG" | tr -d ' ') -eq 1 ]] \
  || fail "expected one systemctl call: $(cat "$SYSTEMCTL_CALL_LOG")"
[[ $(cat "$SYSTEMCTL_CALL_LOG") == "stop buildkite-agent" ]] \
  || fail "unexpected systemctl call: $(cat "$SYSTEMCTL_CALL_LOG")"
[[ $output == *"All buildkite-agent processes have stopped"* ]] \
  || fail "unexpected output: $output"

echo "Auto Scaling lifecycle termination marks the instance for replacement before stopping the agent"
