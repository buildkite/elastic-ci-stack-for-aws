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

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].[Name]' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-.*-managedsecretsbucket' \
  | xargs -n1 -t -I% aws s3 rb s3://% --force

# Do this before deleting the stacks so we don't race with stack-managed log
# groups
echo "--- Deleting old lambda logs after ${cutoff_date_milli}"
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/buildkite-aws-stack-test-" \
  --query "$(printf 'logGroups[?creationTime<`%s`].[logGroupName]' "$cutoff_date_milli" )" \
  --output text \
  | xargs -n1 -t -I% aws logs delete-log-group --log-group-name "%"

echo "--- Deleting old cloudformation stacks"
aws cloudformation describe-stacks \
  --output text \
  --query "$(printf 'Stacks[?CreationTime<`%s`].[StackName]' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-(linux|windows)-(amd64|arm64)-[[:digit:]]+|buildkite-elastic-ci-stack-service-role-[[:digit:]]+' \
  | xargs -n1 -t -I% aws cloudformation delete-stack --stack-name "%"

echo "--- Deleting old packer builders"
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Packer Builder" \
  --query "$(printf 'Reservations[].Instances[?LaunchTime<`%s`].[InstanceId]' "$cutoff_date")" \
  --output text \
  | xargs -n1 -t -I% aws ec2 terminate-instances --instance-ids "%"
