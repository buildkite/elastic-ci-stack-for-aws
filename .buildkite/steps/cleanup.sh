#!/bin/bash
# shellcheck disable=SC2016
set -uo pipefail

cutoff_date=$(date --date='-2 days' +%Y-%m-%d)

if [[ -n "${AWS_STACK_NAME:-}" ]] ; then
  echo "--- Deleting stack $AWS_STACK_NAME"
  aws cloudformation delete-stack --stack-name "$AWS_STACK_NAME"
fi

echo "--- Deleting test managed secrets buckets created"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?CreationDate<`%s`].Name' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-managedsecrets' \
  | xargs -n1 -I% aws s3 rb s3://% --force  

echo "--- Deleting old cloudformation stacks"
aws cloudformation describe-stacks \
  --output text \
  --query "$(printf 'Stacks[?CreationTime<`%s`].StackName' "$cutoff_date" )" \
  | xargs -n1 \
  | grep -E 'buildkite-aws-stack-test-\d+' \
  | xargs -n1 -I% aws cloudformation delete-stack --stack-name "%"
