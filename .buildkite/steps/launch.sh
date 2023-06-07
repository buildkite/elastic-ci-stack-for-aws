#!/bin/bash
set -eu

os="${1:-linux}"
arch="${2:-amd64}"
stack_name="buildkite-aws-stack-test-${os}-${arch}-${BUILDKITE_BUILD_NUMBER}"
stack_queue_name="testqueue-${os}-${arch}-${BUILDKITE_BUILD_NUMBER}"

# download parfait binary
wget -N https://github.com/lox/parfait/releases/download/v1.1.3/parfait_linux_amd64
mv parfait_linux_amd64 parfait
chmod +x ./parfait

vpc_id=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[*].[SubnetId,AvailabilityZone]" --output text)
subnet_ids=$(awk '{print $1}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')
az_ids=$(awk '{print $2}' <<< "$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')

image_id=$(buildkite-agent meta-data get "${os}_${arch}_image_id")
echo "Using AMI $image_id for $os/$arch"

service_role="$(buildkite-agent meta-data get service-role-arn)"
echo "Using service role ${service_role}"

instance_type="t3.nano"
instance_disk="10"

if [[ "$os" == "windows" ]] ; then
  instance_type="m5.large"
  instance_disk="100"
fi

if [[ "$arch" == "arm64" ]] ; then
  instance_type="m6g.large"
fi

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
    "ParameterValue": "${AWS_KEYPAIR:-aws-stack-test}"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "${instance_type}"
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
    "ParameterValue": "${instance_disk}"
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
    "ParameterKey": "ScaleInIdlePeriod",
    "ParameterValue": "60"
  }
]
EOF

echo "--- Building templates"
make "mappings-for-${os}-${arch}-image" build/aws-stack.yml "IMAGE_ID=$image_id"

echo "--- Validating templates"
make validate

echo "--- Creating stack ${stack_name}"
make create-stack "STACK_NAME=$stack_name" "SERVICE_ROLE=$service_role"

echo "+++ ⌛️ Waiting for update to complete"
./parfait watch-stack "${stack_name}"
