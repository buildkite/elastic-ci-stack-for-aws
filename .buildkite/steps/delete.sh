#!/bin/bash
set -euo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
stack_name="buildkite-aws-stack-test-${os}-${arch}-${BUILDKITE_BUILD_NUMBER}"

secrets_bucket=$(aws cloudformation describe-stacks \
	--stack-name "${stack_name}" \
	--query "Stacks[0].Outputs[?OutputKey=='ManagedSecretsBucket'].OutputValue" \
	--output text)

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
