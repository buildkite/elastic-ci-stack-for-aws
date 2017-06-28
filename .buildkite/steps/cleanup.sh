#!/bin/bash
# shellcheck disable=SC2016
set -euo pipefail

cutoff_date=$(date --date='-2 days' +%Y-%m-%d)

echo "--- Deleting stack $AWS_STACK_NAME"
aws cloudformation delete-stack --stack-name "$AWS_STACK_NAME"

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf '[?CreationDate<`%s`].Name' "$cutoff_date" )" |
  grep -E 'buildkite-aws-stack-test(-\d+)?-managed' || true

echo "--- Deleting old cloudformation stacks"
aws cloudformation describe-stacks \
  --output text \
  --query "$(printf 'Stacks[?CreationTime<`%s`].StackName' "$cutoff_date" )" |
  grep -E 'buildkite-aws-stack-test-(\d+)' || true
