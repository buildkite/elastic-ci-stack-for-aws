#!/bin/bash
set -euo pipefail

stack_name="buildkite"
stack_path="${BUILDKITE_BRANCH}/${BUILDKITE_COMMIT}.aws-stack.yml"

echo "--- :cloudformation: Waiting for any previous updates to complete"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"

echo "--- :lambda: Invoking updateElasticStack function"
output=$(aws lambda invoke \
  --invocation-type RequestResponse \
  --function-name updateElasticStack \
  --region us-east-1 \
  --log-type Tail \
  --payload "{\"StackName\":\"$stack_name\",\"StackPath\":\"$stack_path\"}" \
  output.json) || (
  echo "$output"
  exit 1
)

jq '.' < output.json

if [[ "$(jq --raw-output '.errorMessage' < output.json)" == "No updates are to be performed." ]] ; then
  echo "+++ No updates are needed! Stack is up-to-date"
  exit 0
fi

echo "--- :cloudformation: Waiting for stack update to complete"
aws cloudformation wait stack-update-complete \
  --stack-name "$stack_name"
