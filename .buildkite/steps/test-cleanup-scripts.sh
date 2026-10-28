#!/bin/bash
# Runs cleanup-packer.sh and cleanup.sh against a stub aws on PATH. The stub
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
"s3api list-buckets --output text --query "*) ;;
"logs describe-log-groups --log-group-name-prefix /aws/lambda/buildkite-aws-stack-test- "*) ;;
"cloudformation describe-stacks --output text --query Stacks[?CreationTime<"*) printf '%b' "${STUB_STACKS:-}" ;;
"cloudformation describe-stacks --output text --query Stacks[].[StackName]") printf '%b' "${STUB_LIVE_STACKS:-}" ;;
"cloudformation delete-stack --stack-name "*) ;;
"cloudformation wait stack-delete-complete --stack-name "*) ;;
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
# Fails unless the first call matching $1 comes before the first matching $2.
expect_order() {
  local a b
  a="$(grep -n -m1 -E "$1" "$STUB_DIR/calls" | cut -d: -f1 || true)"
  b="$(grep -n -m1 -E "$2" "$STUB_DIR/calls" | cut -d: -f1 || true)"
  [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]] || fail "expected '$1' before '$2'"
}

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

# --- cleanup.sh --------------------------------------------------------------

stacks="buildkite-aws-stack-test-linux-amd64-10\nbuildkite-aws-stack-test-linux-amd64-cis-10\nbuildkite-elastic-ci-stack-service-role-10\n"

# After the waits, only the role and an unrelated stack are live.
check "cleanup: builders first, then test stacks deleted and waited for before roles" 0 cleanup.sh \
  STUB_INSTANCES="$instances" STUB_STACKS="$stacks" \
  STUB_LIVE_STACKS="buildkite-elastic-ci-stack-service-role-10\nbuildkite-aws-stack\n"
expect_order '^ec2 terminate-instances' '^s3api list-buckets'
for stack in buildkite-aws-stack-test-linux-amd64-10 buildkite-aws-stack-test-linux-amd64-cis-10; do
  expect_order "^cloudformation wait stack-delete-complete --stack-name ${stack}$" \
    '^cloudformation describe-stacks --output text --query Stacks\[\]'
done
expect_order '^cloudformation describe-stacks --output text --query Stacks\[\]' \
  '^cloudformation delete-stack --stack-name buildkite-elastic-ci-stack-service-role-10$'

# The old role's build has a test stack younger than the cutoff, so it only
# shows up in the unfiltered listing.
check "cleanup: a live younger test stack keeps every service role" 0 cleanup.sh \
  STUB_STACKS="buildkite-elastic-ci-stack-service-role-10\n" \
  STUB_LIVE_STACKS="buildkite-elastic-ci-stack-service-role-10\nbuildkite-aws-stack-test-windows-amd64-10\n"
expect_no_call 'delete-stack'

for failing in 'cloudformation describe-stacks' \
  'cloudformation delete-stack --stack-name buildkite-aws-stack-test-linux-amd64-10$' \
  'cloudformation wait stack-delete-complete --stack-name buildkite-aws-stack-test-linux-amd64-cis-10$' \
  'cloudformation describe-stacks --output text --query Stacks\[\]'; do
  check "cleanup: ${failing} failure keeps every service role" 1 cleanup.sh \
    STUB_STACKS="$stacks" STUB_FAIL="^${failing}"
  expect_no_call 'delete-stack --stack-name buildkite-elastic-ci-stack-service-role-'
done

check "cleanup: Packer failure doesn't stop the rest, but fails the run" 1 cleanup.sh \
  STUB_STACKS="$stacks" STUB_FAIL='^ec2 describe-instances'
expect_call '^cloudformation delete-stack --stack-name buildkite-elastic-ci-stack-service-role-10$'

if [[ "$failures" -gt 0 ]]; then
  echo "${failures} check(s) failed"
  exit 1
fi
echo "All ${run_number} cleanup script runs passed"
