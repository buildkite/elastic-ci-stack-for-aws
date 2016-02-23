#!/bin/bash
set -eu

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

query_bk_agent_api() {
  curl --show-error --silent -f -H "Authorization: Bearer $BUILDKITE_AWS_STACK_API_TOKEN" \
    "https://api.buildkite.com/v1/organizations/$BUILDKITE_AWS_STACK_ORG_SLUG/agents$*"
}

create_bk_pipeline() {
  curl --show-error --silent -f -X POST -H "Authorization: Bearer $BUILDKITE_AWS_STACK_API_TOKEN" \
    "https://api.buildkite.com/v2/organizations/$BUILDKITE_AWS_STACK_ORG_SLUG/pipelines" \
    -d @-
}

create_bk_build() {
  local pipeline="$1"
  curl --show-error --silent -f -X POST -H "Authorization: Bearer $BUILDKITE_AWS_STACK_API_TOKEN" \
    "https://api.buildkite.com/v2/organizations/$BUILDKITE_AWS_STACK_ORG_SLUG/pipelines/$pipeline/builds" \
    -d @-
}

bk_build_status() {
  local pipeline="$1"
  local build="$2"
  if ! build_json=$(curl --show-error --silent -f -H "Authorization: Bearer $BUILDKITE_AWS_STACK_API_TOKEN" \
      "https://api.buildkite.com/v2/organizations/$BUILDKITE_AWS_STACK_ORG_SLUG/pipelines/$pipeline/builds/$build") ; then
    echo $build_json >&2
    return 1
  fi
  awk '/state/ {print $2}' <<< "$build_json" | head -n1 | cut -d\" -f2
}

bk_build_follow() {
  local pipeline="$1"
  local build="$2"

  until status=$(bk_build_status "$pipeline" "$build"); [[ $status =~ (scheduled|running) ]] ; do
    echo "Build status is $status, continuing to poll"
    sleep 20
  done
  if [[ $status =~ failed ]] ; then
    stack_events "$1"
    echo -e "\033[33;31mBuild failed!\033[0m"
    return 1
  else
    echo -e "\033[33;32mBuild completed successfully\033[0m"
  fi
}

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
    "ParameterKey": "BuildkiteQueue",
    "ParameterValue": "testqueue-$$"
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

export stack_name="buildkite-aws-stack-test-$$"
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

echo
echo "--- Waiting for agents to start"
sleep 10

echo "--- Checking agent has registered correctly"
if ! query_bk_agent_api "?name=${stack_name}-1" | grep -C 20 --color=always '"connection_state": "connected"' ; then
  echo -e "\033[33;31mAgent failed to connect to buildkite\033[0m"
  exit 1
else
  echo -e "\033[33;32mAgent connected successfully\033[0m"
fi

echo "--- Creating buildkite pipeline"
create_bk_pipeline_body=$(cat << EOF
{
  "name": "${stack_name}",
  "repository": "git@github.com:buildkite/buildkite-aws-stack.git",
  "steps": [
    {
      "type": "script",
      "name": "Sleep",
      "command": "sleep 10",
      "agent_query_rules": ["queue=testqueue-$$","stack_name=${stack_name}"]
    }
  ]
}
EOF
)

if ! pipeline_json=$(create_bk_pipeline <<< "$create_bk_pipeline_body") ; then
  echo -e "\033[33;31mFailed to create buildkite pipeline\033[0m"
  exit 1
fi

if ! pipeline_slug=$(awk '/slug/ {print $2}' <<< "$pipeline_json" | cut -d\" -f2) ; then
  echo -e "\033[33;31mFailed to find a pipeline slug\033[0m"
  exit 1
fi

echo "$pipeline_json"

echo "--- Creating buildkite build in $pipeline_slug"
create_bk_build_body=$(cat << EOF
{
  "commit": "${BUILDKITE_COMMIT}",
  "branch": "${BUILDKITE_BRANCH}",
  "message": "Testing all the things :rocket:",
  "env": {
    "MY_ENV_VAR": "some_value"
  }
}
EOF
)

if ! build_json=$(create_bk_build "$pipeline_slug" <<< "$create_bk_build_body") ; then
  echo -e "\033[33;31mFailed to create buildkite build\033[0m"
  exit 1
fi

echo "$build_json"

echo "--- Waiting for build to complete"
bk_build_follow "$pipeline_slug" "1"

buildkite-agent meta-data set bk_pipeline_slug "$pipeline_slug"
buildkite-agent meta-data set stack_name "$stack_name"
