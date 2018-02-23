#!/bin/bash
# shellcheck disable=SC1117
set -eu

vpc_id=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].[SubnetId,AvailabilityZone]" --output text)
subnet_ids=$(awk '{print $1}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')
az_ids=$(awk '{print $2}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')

image_id=$(buildkite-agent meta-data get image_id)
echo "Using AMI $image_id"

cat << EOF > config.json
[
  {
    "ParameterKey": "BuildkiteOrgSlug",
    "ParameterValue": "$BUILDKITE_AWS_STACK_ORG_SLUG"
  },
  {
    "ParameterKey": "BuildkiteAgentToken",
    "ParameterValue": "$BUILDKITE_AWS_STACK_AGENT_TOKEN"
  },
  {
    "ParameterKey": "BuildkiteApiAccessToken",
    "ParameterValue": "$BUILDKITE_AWS_STACK_API_TOKEN"
  },
  {
    "ParameterKey": "BuildkiteQueue",
    "ParameterValue": "${AWS_STACK_QUEUE_NAME}"
  },
  {
    "ParameterKey": "KeyName",
    "ParameterValue": "${AWS_KEYPAIR:-default}"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t2.nano"
  },
  {
    "ParameterKey": "VpcId",
    "ParameterValue": "${vpc_id}"
  },
  {
    "ParameterKey": "Subnets",
    "ParameterValue": "${subnet_ids}"
  },
  {
    "ParameterKey": "AvailabilityZones",
    "ParameterValue": "${az_ids}"
  },
  {
    "ParameterKey": "MaxSize",
    "ParameterValue": "1"
  },
  {
    "ParameterKey": "AgentsPerInstance",
    "ParameterValue": "3"
  },
  {
    "ParameterKey": "ECRAccessPolicy",
    "ParameterValue": "readonly"
  },
  {
    "ParameterKey": "RootVolumeSize",
    "ParameterValue": "10"
  }
]
EOF

version=$(git describe --tags --candidates=1)

cat << EOF > templates/mappings.yml
Mappings:
  AWSRegion2AMI:
    us-east-1     : { AMI: $image_id }
EOF

make build validate

echo "--- Creating stack ${AWS_STACK_NAME} ($version)"
aws cloudformation create-stack \
  --output text \
  --stack-name "${AWS_STACK_NAME}" \
  --disable-rollback \
  --template-body "file://${PWD}/build/aws-stack.json" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --parameters "$(cat config.json)"

echo "--- Waiting for stack to complete"
aws cloudformation wait stack-create-complete --stack-name "${AWS_STACK_NAME}"
