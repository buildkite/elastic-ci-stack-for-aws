#!/bin/bash -euo pipefail

JSON_FILE=$(cd $(dirname $0)/../; pwd)/buildkite-cloudformation.json
KEY_PAIR=${KEY_PAIR:-default}
STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
BUILDKITE_SLUG=${1:-}
BUILDKITE_AGENT_TOKEN=${2:-}
BUILDKITE_API_TOKEN=${3:-}

if [[ -z $BUILDKITE_SLUG || -z $BUILDKITE_AGENT_TOKEN || -z $BUILDKITE_API_TOKEN ]] ; then
  echo "usage: $0 <org slug> <agent token> <api token>"
  exit 1
fi

echo "Generating $JSON_FILE"
cfoo $(dirname $0)/../buildkite-cloudformation.yml > $JSON_FILE

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://$JSON_FILE \
  --capabilities CAPABILITY_IAM \
  --disable-rollback \
  --parameters \
    ParameterKey=KeyName,ParameterValue=$KEY_PAIR \
    ParameterKey=BuildkiteAgentToken,ParameterValue=$BUILDKITE_AGENT_TOKEN \
    ParameterKey=BuildkiteApiToken,ParameterValue=$BUILDKITE_API_TOKEN \
    ParameterKey=BuildkiteOrgSlug,ParameterValue=$BUILDKITE_SLUG