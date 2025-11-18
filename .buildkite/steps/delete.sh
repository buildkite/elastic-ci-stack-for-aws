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

echo "--- Removing scale-in protection from instances"

asg_name=$(aws cloudformation describe-stack-resources \
  --no-cli-pager \
  --stack-name "${stack_name}" \
  --logical-resource-id AgentAutoScaleGroup \
  --query 'StackResources[0].PhysicalResourceId' \
  --output text)

instance_ids=$(aws autoscaling describe-auto-scaling-groups \
  --no-cli-pager \
  --auto-scaling-group-names "${asg_name}" \
  --query 'AutoScalingGroups[0].Instances[*].InstanceId' \
  --output text)

if [ -n "$instance_ids" ]; then
  for instance_id in $instance_ids; do
    echo "Removing scale-in protection from ${instance_id}"
    aws autoscaling set-instance-protection \
      --instance-ids "$instance_id" \
      --auto-scaling-group-name "${asg_name}" \
      --no-protected-from-scale-in || true
  done
fi

echo "--- Deleting stack $stack_name"
aws cloudformation delete-stack --stack-name "$stack_name"
aws cloudformation wait stack-delete-complete --stack-name "$stack_name"

echo "--- Deleting buckets for $stack_name"
aws s3 rb "s3://${secrets_bucket}" --force
aws s3 rb "s3://${secrets_logging_bucket}" --force
