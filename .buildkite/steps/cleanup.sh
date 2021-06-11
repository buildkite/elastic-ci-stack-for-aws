#!/bin/bash
# shellcheck disable=SC2016
set -uxo pipefail

delete_test_stack() {
  local os="$1"
  local stack_name; stack_name="buildkite-aws-stack-test-${os}-${BUILDKITE_BUILD_NUMBER}"

  secrets_bucket=$(aws cloudformation describe-stacks \
    --stack-name "${stack_name}" \
    --query 'Stacks[0].Outputs[?OutputKey==`ManagedSecretsBucket`].OutputValue' \
    --output text)

  secrets_logging_bucket=$(aws cloudformation describe-stacks \
    --stack-name "${stack_name}" \
    --query 'Stacks[0].Outputs[?OutputKey==`ManagedSecretsLoggingBucket`].OutputValue' \
    --output text)

  echo "--- Deleting stack $stack_name"
  aws cloudformation delete-stack --stack-name "$stack_name"

  echo "--- Deleting buckets for $stack_name"
  aws s3 rb "s3://${secrets_bucket}" --force
  aws s3 rb "s3://${secrets_logging_bucket}" --force
}

if [[ -n "${BUILDKITE_BUILD_NUMBER:-}" ]] ; then
  delete_test_stack "windows-amd64"
  delete_test_stack "linux-amd64"
  delete_test_stack "linux-arm64"
fi

if [[ $OSTYPE =~ ^darwin ]] ; then
  cutoff_date=$(gdate --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(gdate --date='-1 days' +%s%3N)
else
  cutoff_date=$(date --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(date --date='-1 days' +%s%3N)
fi

echo "--- Cleaning up resources older than ${cutoff_date}"

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].[Name]' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-.*-managedsecretsbucket' \
  | xargs -n1 -t -I% aws s3 rb s3://% --force

echo "--- Deleting old cloudformation stacks"
aws cloudformation describe-stacks \
  --output text \
  --query "$(printf 'Stacks[?CreationTime<`%s`].[StackName]' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-(linux|windows)-(amd64|arm64)-[[:digit:]]+' \
  | xargs -n1 -t -I% aws cloudformation delete-stack --stack-name "%"

echo "--- Deleting old packer builders"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Packer Builder" \
  --query "$(printf 'Reservations[].Instances[?LaunchTime<`%s`].[InstanceId]' "$cutoff_date")" \
  --output text \
  | xargs -n1 -t -I% aws ec2 terminate-instances --instance-ids "%"

echo "--- Deleting old lambda logs after ${cutoff_date_milli}"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/buildkite-aws-stack-test-" \
  --query "$(printf 'logGroups[?creationTime<`%s`].[logGroupName]' "$cutoff_date_milli" )" \
  --output text \
  | xargs -n1 -t -I% aws logs delete-log-group --log-group-name "%"
