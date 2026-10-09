#!/bin/bash
# Runs cleanup-packer.sh against a stub aws on PATH. The stub
# answers only the calls the scripts should make; any other call fails the
# test. Needs Bash 4.4+ and GNU date.
set -euo pipefail

steps_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

date_cmd="date"
if [[ $OSTYPE =~ ^darwin ]]; then
  date_cmd=gdate
fi
old="$("$date_cmd" -u -d '-24 hours -1 minute' +%Y-%m-%dT%H:%M:%S+00:00)"
young="$("$date_cmd" -u -d '-23 hours -59 minutes' +%Y-%m-%dT%H:%M:%S+00:00)"

mkdir "$work/bin"
cat >"$work/bin/aws" <<'EOF'
#!/bin/bash
echo "$*" >>"$STUB_DIR/calls"
if [[ -n "${STUB_FAIL:-}" && "$*" =~ $STUB_FAIL ]]; then
  echo "An error occurred (Stubbed) for: $*" >&2
  exit 254
fi
case "$*" in
"configure get region")
  [[ -n "${STUB_CONFIG_REGION:-}" ]] || exit 1
  echo "$STUB_CONFIG_REGION"
  ;;
"sts get-caller-identity --region us-east-1 --query Account --output text")
  echo "${STUB_ACCOUNT:-172840064832}"
  ;;
"ec2 describe-instances --region us-east-1 --filters Name=tag:Name,Values=Packer Builder Name=tag:ManagedBy,Values=elastic-ci-stack-for-aws Name=tag:Purpose,Values=disposable-ci Name=tag-key,Values=BuildNumber Name=instance-state-name,Values=pending,running,stopping,stopped --query Reservations[].Instances[].[InstanceId, LaunchTime] --output text")
  printf '%b' "${STUB_INSTANCES:-}"
  ;;
"ec2 terminate-instances --region us-east-1 --instance-ids "*) ;;
*)
  echo "$*" >>"$STUB_DIR/unexpected"
  echo "unexpected aws call: $*" >&2
  exit 99
  ;;
esac
EOF
chmod +x "$work/bin/aws"

failures=0

# check NAME EXPECTED_STATUS SCRIPT [ENV...]: runs SCRIPT in us-east-1 with
# DRY_RUN unset and the given env assignments.
check() {
  name="$1" expected="$2" script="$3"
  shift 3
  export STUB_DIR="$work/$((++run_number))"
  mkdir "$STUB_DIR"
  touch "$STUB_DIR/calls"
  status=0
  env -u DRY_RUN -u AWS_DEFAULT_REGION PATH="$work/bin:$PATH" AWS_REGION=us-east-1 "$@" "$steps_dir/$script" >"$STUB_DIR/output" 2>&1 || status=$?
  [[ "$status" == "$expected" ]] || fail "exit status ${status}, expected ${expected}"
  [[ ! -s "$STUB_DIR/unexpected" ]] || fail "unexpected aws calls"
}
run_number=0

fail() {
  failures=$((failures + 1))
  echo "FAIL [${name}]: $*"
  sed 's/^/    /' "$STUB_DIR/calls" "$STUB_DIR/output"
}

called() { grep -q -E "$1" "$STUB_DIR/calls"; }
expect_call() { called "$1" || fail "missing call matching: $1"; }
expect_no_call() { ! called "$1" || fail "unexpected call matching: $1"; }

instances="i-old\t${old}\ni-young\t${young}\n"

# --- cleanup-packer.sh -------------------------------------------------------

check "packer: unset DRY_RUN terminates only builders older than 24h" 0 cleanup-packer.sh STUB_INSTANCES="$instances"
expect_call '^ec2 terminate-instances --region us-east-1 --instance-ids i-old --'
expect_no_call 'i-young'

# Match clean-old-amis: presence enables preview, even for false or empty.
for value in true false "" yes; do
  check "packer: DRY_RUN=${value} lists without terminating" 0 cleanup-packer.sh DRY_RUN="$value" STUB_INSTANCES="$instances"
  expect_no_call 'terminate-instances'
  grep -q 'Found: i-old$' "$STUB_DIR/output" || fail "expected i-old to be listed"
done

# Calls name us-east-1 explicitly, but a caller configured elsewhere is refused.
for region_env in "AWS_REGION=us-west-2 AWS_DEFAULT_REGION=us-east-1" "AWS_REGION= AWS_DEFAULT_REGION=us-west-2 STUB_CONFIG_REGION=us-east-1" \
  "AWS_REGION= STUB_CONFIG_REGION=eu-west-1" "AWS_REGION="; do
  # shellcheck disable=SC2086 # split into separate assignments
  check "packer: region from ${region_env} is refused" 1 cleanup-packer.sh $region_env STUB_INSTANCES="$instances"
  expect_no_call '^(sts|ec2) '
done
check "packer: us-east-1 from the CLI config is accepted" 0 cleanup-packer.sh \
  AWS_REGION= STUB_CONFIG_REGION=us-east-1 STUB_INSTANCES="$instances"
expect_call '^ec2 terminate-instances --region us-east-1 --instance-ids i-old --'

check "packer: another account is refused before listing" 1 cleanup-packer.sh STUB_ACCOUNT=111111111111 STUB_INSTANCES="$instances"
expect_no_call 'ec2 '

for failing in 'sts get-caller-identity' 'ec2 describe-instances' 'ec2 terminate-instances'; do
  check "packer: ${failing} failure fails the script" 254 cleanup-packer.sh STUB_FAIL="^${failing}" STUB_INSTANCES="$instances"
done

check "packer: unreadable launch time fails without terminating" 1 cleanup-packer.sh STUB_INSTANCES="i-odd\tnot-a-date\n${instances}"
expect_no_call 'terminate-instances'

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} check(s) failed"
  exit 1
fi
echo "All ${run_number} cleanup script runs passed"
