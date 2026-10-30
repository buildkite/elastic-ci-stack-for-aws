#!/bin/bash
# shellcheck disable=SC2016
set -uo pipefail

# Reclaim test resources older than a day, including leftovers from canceled
# builds. Called by normal builds and the scheduled cleaner. Any set DRY_RUN
# value previews all deletions.

if [[ $OSTYPE =~ ^darwin ]]; then
  cutoff_date=$(gdate --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(gdate --date='-1 days' +%s%3N)
else
  cutoff_date=$(date --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(date --date='-1 days' +%s%3N)
fi

failed=0

delete_resource() {
  if [[ -n "${DRY_RUN+set}" ]]; then
    echo "DRY_RUN: $*"
  else
    "$@"
  fi
}

# First, so failures in the cleanup below can't stop builders being reclaimed.
"$(dirname "${BASH_SOURCE[0]}")/cleanup-packer.sh" || failed=1

echo "--- Cleaning up resources older than ${cutoff_date}"

echo "--- Cleaning up test managed secrets and logging buckets"
buckets="$(aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].[Name]' "$cutoff_date")")" || {
  buckets=""
  failed=1
}
for bucket in $buckets; do
  if [[ "$bucket" =~ ^buildkite-aws-stack-test-.*-(managedsecretsbucket|managedsecretsloggingbuc)[[:alnum:]-]*$ ]]; then
    delete_resource aws s3 rb "s3://${bucket}" --force || failed=1
  fi
done

# Do this before deleting the stacks so we don't race with stack-managed log
# groups
echo "--- Cleaning up Lambda log groups older than one day"
log_groups="$(aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/buildkite-aws-stack-test-" \
  --query "$(printf 'logGroups[?creationTime<`%s`].[logGroupName]' "$cutoff_date_milli")" \
  --output text)" || {
  log_groups=""
  failed=1
}
for log_group in $log_groups; do
  delete_resource aws logs delete-log-group --log-group-name "$log_group" || failed=1
done

echo "--- Cleaning up old CloudFormation test stacks"
# Test stacks are deleted through their build's service role, so no role may be
# deleted while any test stack exists. If a listing, deletion or wait fails, or
# a test stack of any age is still live, keep all service roles until the next
# run. Only AWS errors fail this script.
test_stack_re='^buildkite-aws-stack-test-(linux|windows|ubuntu2404)-(amd64|arm64)-([[:alpha:]]+-)?[[:digit:]]+$'
stacks_ok=true
printf -v aged_stacks_query 'Stacks[?CreationTime<`%s`].[StackName]' "$cutoff_date"
stacks="$(aws cloudformation describe-stacks --output text --query "$aged_stacks_query")" || {
  stacks_ok=false
  failed=1
}

deleting=()
for stack in $(xargs -n1 <<<"$stacks" | grep -E "$test_stack_re"); do
  if delete_resource aws cloudformation delete-stack --stack-name "$stack"; then
    deleting+=("$stack")
  else
    stacks_ok=false
    failed=1
  fi
done
if [[ -z "${DRY_RUN+set}" ]]; then
  for stack in "${deleting[@]}"; do
    aws cloudformation wait stack-delete-complete --stack-name "$stack" || {
      stacks_ok=false
      failed=1
    }
  done
fi

# The listing above skips stacks younger than the cutoff, and a role can be
# older than its build's test stacks, so check every live stack.
if [[ "$stacks_ok" == "true" ]]; then
  if live_stacks="$(aws cloudformation describe-stacks --output text --query 'Stacks[].[StackName]')"; then
    live_test_stacks="$(xargs -n1 <<<"$live_stacks" | grep -E "$test_stack_re")"
    if [[ -n "$live_test_stacks" ]]; then
      echo "Test stacks still exist:"
      echo "$live_test_stacks"
      stacks_ok=false
    fi
  else
    stacks_ok=false
    failed=1
  fi
fi

echo "--- Cleaning up old CloudFormation service-role stacks"
if [[ -n "${DRY_RUN+set}" ]]; then
  echo "DRY_RUN: Service-role deletions require all test stacks to be gone"
fi
if [[ "$stacks_ok" == "true" || -n "${DRY_RUN+set}" ]]; then
  for stack in $(xargs -n1 <<<"$stacks" | grep -E '^buildkite-elastic-ci-stack-service-role-[[:digit:]]+$'); do
    delete_resource aws cloudformation delete-stack --stack-name "$stack" || failed=1
  done
else
  echo "Keeping all service-role stacks: test stacks could not be listed or deleted, or some still exist" >&2
fi

exit "$failed"
