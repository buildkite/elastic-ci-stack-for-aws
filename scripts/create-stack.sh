#!/bin/bash -euo pipefail

JSON_FILE=$(cd $(dirname $0)/../; pwd)/buildkite-cloudformation.json
KEY_PAIR=${KEY_PAIR:-default}
STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
BUILDKITE_TOKEN=${1:-}

if [[ -z $BUILDKITE_TOKEN ]] ; then
  echo "usage: $0 <buildkite token>"
  exit 1
fi

echo "Generating $JSON_FILE"
cfoo $(dirname $0)/../buildkite-cloudformation.yml > $JSON_FILE

aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body file://$JSON_FILE \
  --disable-rollback \
  --parameters \
    ParameterKey=KeyName,ParameterValue=$KEY_PAIR \
    ParameterKey=BuildkiteToken,ParameterValue=$BUILDKITE_TOKEN