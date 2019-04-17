#!/bin/bash
# shellcheck disable=SC1117
set -eu

os="${1:-linux}"

# download parfait binary
wget -N https://github.com/lox/parfait/releases/download/v1.1.3/parfait_linux_amd64
mv parfait_linux_amd64 parfait
chmod +x ./parfait

vpc_id=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].[SubnetId,AvailabilityZone]" --output text)
subnet_ids=$(awk '{print $1}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')
az_ids=$(awk '{print $2}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')

image_id=$(buildkite-agent meta-data get "${os}_image_id")
echo "Using AMI $image_id for $os"

stack_name="buildkite-aws-stack-test-${os}-${BUILDKITE_BUILD_NUMBER}"
stack_queue_name="testqueue-${os}-${BUILDKITE_BUILD_NUMBER}"

cat << EOF > config.json
[
  {
    "ParameterKey": "BuildkiteAgentToken",
    "ParameterValue": "$BUILDKITE_AWS_STACK_AGENT_TOKEN"
  },
  {
    "ParameterKey": "BuildkiteQueue",
    "ParameterValue": "${stack_queue_name}"
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
    "ParameterKey": "InstanceOperatingSystem",
    "ParameterValue": "${os}"
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
  },
  {
    "ParameterKey": "EnableDockerUserNamespaceRemap",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "EnableAgentGitMirrorsExperiment",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "EnableExperimentalLambdaBasedAutoscaling",
    "ParameterValue": "true"
  }
]
EOF

echo "--- Building templates"
make "mappings-for-${os}-image" build/aws-stack.yml "IMAGE_ID=$image_id"

echo "--- Validating templates"
make validate

echo "--- Creating stack ${stack_name}"
make create-stack "STACK_NAME=$stack_name"

echo "+++ ⌛️ Waiting for update to complete"
./parfait watch-stack "${stack_name}"
