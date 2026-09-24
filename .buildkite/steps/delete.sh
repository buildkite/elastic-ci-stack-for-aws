#!/bin/bash
set -euo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
variant="${3:-}"
if [[ -n "$variant" ]]; then
  stack_name="buildkite-aws-stack-test-${os}-${arch}-${variant}-${BUILDKITE_BUILD_NUMBER}"
else
  stack_name="buildkite-aws-stack-test-${os}-${arch}-${BUILDKITE_BUILD_NUMBER}"
fi

describe_error=$(mktemp)
trap 'rm -f "$describe_error"' EXIT

if secrets_bucket=$(aws cloudformation describe-stacks \
  --stack-name "${stack_name}" \
  --query "Stacks[0].Outputs[?OutputKey=='ManagedSecretsBucket'].OutputValue" \
  --output text 2>"$describe_error"); then
  cat "$describe_error" >&2
else
  status=$?
  # Cleanup also runs when a failed dependency prevented stack creation.
  if grep -Fq "(ValidationError) when calling the DescribeStacks operation: Stack with id ${stack_name} does not exist" "$describe_error"; then
    echo "--- Stack $stack_name does not exist; nothing to delete"
    exit 0
  fi
  cat "$describe_error" >&2
  exit "$status"
fi

secrets_logging_bucket=$(aws cloudformation describe-stacks \
  --stack-name "${stack_name}" \
  --query "Stacks[0].Outputs[?OutputKey=='ManagedSecretsLoggingBucket'].OutputValue" \
  --output text)

echo "--- Deleting stack $stack_name"
aws cloudformation delete-stack --stack-name "$stack_name"
aws cloudformation wait stack-delete-complete --stack-name "$stack_name"

echo "--- Deleting buckets for $stack_name"
aws s3 rb "s3://${secrets_bucket}" --force
aws s3 rb "s3://${secrets_logging_bucket}" --force
