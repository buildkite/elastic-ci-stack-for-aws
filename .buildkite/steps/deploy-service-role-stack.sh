#!/bin/bash
set -euo pipefail

stack_name="buildkite-elastic-ci-stack-service-role-${BUILDKITE_BUILD_NUMBER}"
buildkite-agent meta-data set service-role-stack-name "${stack_name}"

aws cloudformation deploy --template-file templates/service-role.yml --stack-name "${stack_name}" --region us-east-1 --capabilities CAPABILITY_IAM

role_arn="$(aws cloudformation describe-stacks --stack-name "${stack_name}" --region us-east-1 --query "Stacks[0].Outputs[?OutputKey=='RoleArn'].OutputValue" --output text)"
buildkite-agent meta-data set service-role-arn "${role_arn}"