#!/bin/bash
set -euo pipefail

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
subnet_ids=$(awk '{print $1}' <<<"$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')
az_ids=$(awk '{print $2}' <<<"$subnets" | tr ' ' ',' | tr '\n' ',' | sed 's/,$//')

image_id=$(buildkite-agent meta-data get "${os}_${arch}_image_id")
echo "Using AMI $image_id for $os/$arch"

service_role="$(buildkite-agent meta-data get service-role-arn)"
echo "Using service role ${service_role}"

instance_type="t3.small"
instance_disk="10"

if [[ "$os" == "windows" ]]; then
  instance_type="m5.large"
  instance_disk="100"
fi

if [[ "$arch" == "arm64" ]]; then
  instance_type="m6gd.medium"
  enable_instance_storage="true"
fi

cat <<EOF >config.json
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
    "ParameterKey": "InstanceTypes",
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
    "ParameterKey": "BuildkiteAgentEnableGitMirrors",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "ScaleInIdlePeriod",
    "ParameterValue": "60"
  },
  {
    "ParameterKey": "EnableInstanceStorage",
    "ParameterValue": "${enable_instance_storage:-false}"
  },
  {
    "ParameterKey": "BuildkiteAdditionalSudoPermissions",
    "ParameterValue": "/usr/local/bin/goss"
  }
]
EOF

echo "--- Building templates"
make "mappings-for-${os}-${arch}-image" build/aws-stack.yml "IMAGE_ID=$image_id"

echo "--- Uploading test template to S3"
s3_bucket="buildkite-agent-elastic-stack-test-templates"
s3_key="templates/build-${BUILDKITE_BUILD_NUMBER}/${os}-${arch}/${BUILDKITE_COMMIT}.aws-stack.yml"

# s3 cp requires old path style, cloudformation requires new http style. sigh.
upload_location="s3://${s3_bucket}/${s3_key}"
download_location="https://s3.amazonaws.com/${s3_bucket}/${s3_key}"

aws s3 cp --content-type 'text/yaml' "build/aws-stack.yml" "$upload_location"

echo "--- Validating templates"
aws --no-cli-pager cloudformation validate-template \
  --output text \
  --template-url "$download_location"

echo "--- Creating stack ${stack_name}"
aws cloudformation create-stack \
  --output text \
  --stack-name "${stack_name}" \
  --template-url "$download_location" \
  --disable-rollback \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameters "$(cat config.json)" \
  --role-arn "$service_role"

echo "+++ ⌛️ Waiting for update to complete"
./parfait watch-stack "${stack_name}"
