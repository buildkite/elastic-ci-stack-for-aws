#!/bin/bash
# shellcheck disable=SC2016
set -uxo pipefail

########################################################
# We make an attempt to clean up the specific resources created during this pipeline elsewhere. However
# sometimes that fails, are various CloudFormation Stacks, S3 Buckets and CloudWatch Log Groups can be
# left around.
#
# This is a safety net at the end of the build that attempts to delete any resources created by this
# pipeline more than a day ago, regardless of if they were created in the current build or not.
########################################################

if [[ $OSTYPE =~ ^darwin ]]; then
  cutoff_date=$(gdate --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(gdate --date='-1 days' +%s%3N)
else
  cutoff_date=$(date --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(date --date='-1 days' +%s%3N)
fi

failed=0

# First, so failures in the cleanup below can't stop builders being reclaimed.
"$(dirname "${BASH_SOURCE[0]}")/cleanup-packer.sh" || failed=1

echo "--- Cleaning up resources older than ${cutoff_date}"

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].[Name]' "$cutoff_date")" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-.*-managedsecretsbucket' \
  | xargs -n1 -t -I% aws s3 rb s3://% --force

echo "--- Deleting test managed secrets logging buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].[Name]' "$cutoff_date")" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test--managedsecretsloggingbuc' \
  | xargs -n1 -t -I% aws s3 rb s3://% --force

# Do this before deleting the stacks so we don't race with stack-managed log
# groups
echo "--- Deleting old lambda logs after ${cutoff_date_milli}"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/buildkite-aws-stack-test-" \
  --query "$(printf 'logGroups[?creationTime<`%s`].[logGroupName]' "$cutoff_date_milli")" \
  --output text \
  | xargs -n1 -t -I% aws logs delete-log-group --log-group-name "%"

echo "--- Deleting old cloudformation stacks for test stacks"
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
  if aws cloudformation delete-stack --stack-name "$stack"; then
    deleting+=("$stack")
  else
    stacks_ok=false
    failed=1
  fi
done
for stack in "${deleting[@]}"; do
  aws cloudformation wait stack-delete-complete --stack-name "$stack" || {
    stacks_ok=false
    failed=1
  }
done

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

echo "--- Deleting old cloudformation stacks for test stack service roles"
if [[ "$stacks_ok" == "true" ]]; then
  for stack in $(xargs -n1 <<<"$stacks" | grep -E 'buildkite-elastic-ci-stack-service-role-[[:digit:]]+'); do
    aws cloudformation delete-stack --stack-name "$stack" || failed=1
  done
else
  echo "Keeping all service-role stacks: test stacks could not be listed or deleted, or some still exist" >&2
fi

exit "$failed"
