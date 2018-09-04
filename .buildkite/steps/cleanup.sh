#!/bin/bash
# shellcheck disable=SC2016
set -uxo pipefail

if [[ $OSTYPE =~ ^darwin ]] ; then
  cutoff_date=$(gdate --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(gdate --date='-1 days' +%s%3N)
else
  cutoff_date=$(date --date='-1 days' +%Y-%m-%d)
  cutoff_date_milli=$(date --date='-1 days' +%s%3N)
fi

echo "--- Cleaning up resources older than ${cutoff_date}"

if [[ -n "${AWS_STACK_NAME:-}" ]] ; then
  echo "--- Deleting stack $AWS_STACK_NAME"
  aws cloudformation delete-stack --stack-name "$AWS_STACK_NAME"
fi

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].Name' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-(\d+-)?managedsecrets' \
  | xargs -n1 -t -I% aws s3 rb s3://% --force

echo "--- Deleting old cloudformation stacks"
aws cloudformation describe-stacks \
  --output text \
  --query "$(printf 'Stacks[?CreationTime<`%s`].StackName' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-\d+' \
  | xargs -n1 -t -I% aws cloudformation delete-stack --stack-name "%"

echo "--- Deleting old packer builders"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Packer Builder" \
  --query "$(printf 'Reservations[].Instances[?LaunchTime<`%s`].InstanceId' "$cutoff_date")" \
  --output text \
  | xargs -n1 -t -I% aws ec2 terminate-instances --instance-ids "%"

echo "--- Deleting old lambda logs after ${cutoff_date_milli}"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/buildkite-aws-stack-test-" \
  --query "$(printf 'logGroups[?creationTime<`%s`].logGroupName' "$cutoff_date_milli" )" \
  --output text \
  | xargs -n1 -t -I% aws logs delete-log-group --log-group-name "%"
