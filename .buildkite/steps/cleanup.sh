#!/bin/bash
set -eu

stack_name=$(buildkite-agent meta-data get stack_name)

echo "--- Deleting stack $stack_name"
aws cloudformation delete-stack --stack-name "$stack_name"

echo "--- Deleting old managed secrets buckets"
aws s3api list-buckets \
  --output text \
  --query "$(printf 'Buckets[?starts_with(Name, `%s`) == `true`][?CreationDate<`%s`].Name' \
    "buildkite-aws-stack-test-managedsecrets" \
    "$(date --date='-2 days' +%Y-%m-%d)" \
  )"
