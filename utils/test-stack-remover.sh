#!/usr/bin/env bash

# The CI for this repo can sometimes leave some stacks lying around - every couple of months we need to clean them up.
# This script will delete any stacks that are in DELETE_FAILED state, that contain the word _test_ in their name, and
# that are not autoscaling stacks (these are child stacks that will be deleted when their parent is deleted)

set -euo pipefail

aws cloudformation list-stacks \
  | jq -r ".StackSummaries[] | {StackName, StackStatus} | select(.StackStatus == \"DELETE_FAILED\").StackName" \
  | grep test \
  | grep -vi autoscaling \
  | sort | uniq \
  | xargs -t -I {} aws cloudformation delete-stack \
    --stack-name {} \
    --role-arn "$ROLE_ARN"
