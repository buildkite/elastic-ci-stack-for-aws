#!/bin/bash
set -eu

## -------------------------------------------------
## functions

stack_status() {
  aws cloudformation describe-stacks --stack-name "$1" --output text --query 'Stacks[].StackStatus'
}

stack_events() {
  aws cloudformation describe-stack-events --stack-name "$1" --output table --query 'sort_by(StackEvents, &Timestamp)[].[
    EventId,
    ResourceStatus
  ]' | sed 1,2d
}

stack_failures() {
  aws cloudformation describe-stack-events --stack-name "$1" --output table --query \
    "sort_by(StackEvents, &Timestamp)[?ResourceStatus=='CREATE_FAILED'].[LogicalResourceId,ResourceStatusReason]" \
  | sed 1,2d
}

stack_follow() {
  until status=$(stack_status "$1"); [[ $status =~ (FAILED|COMPLETE) ]] ; do
    echo "Stack status is $status, continuing to poll"
    sleep 20
  done
  if [[ $status =~ FAILED ]] ; then
    stack_events "$1"
    echo -e "\033[33;31mStack creation failed!\n$(stack_failures "$1")\033[0m"
    return 1
  else
    echo -e "\033[33;32mStack completed successfully\033[0m"
  fi
}

## -------------------------------------------------
## read metadata

stack_name=$(buildkite-agent meta-data get stack_name)
queue_name=$(buildkite-agent meta-data get queue_name)

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
    "ParameterValue": "${queue_name}"
  },
  {
    "ParameterKey": "KeyName",
    "ParameterValue": "${AWS_KEYPAIR:-default}"
  },
  {
    "ParameterKey": "InstanceType",
    "ParameterValue": "t2.micro"
  },
  {
    "ParameterKey": "SecretsBucket",
    "ParameterValue": "${BUILDKITE_AWS_STACK_BUCKET}"
  },
  {
    "ParameterKey": "ImageId",
    "ParameterValue": "${image_id}"
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
  }
]
EOF

make setup clean build validate

echo "--- Creating stack $stack_name"
aws cloudformation create-stack \
  --output text \
  --stack-name "$stack_name" \
  --disable-rollback \
  --template-body "file://${PWD}/build/aws-stack.json" \
  --capabilities CAPABILITY_IAM \
  --parameters "$(cat config.json)"

echo "--- Waiting for stack to complete"
stack_follow "$stack_name"
