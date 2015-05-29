#!/bin/bash

JSON_FILE=$(cd $(dirname $0)/../; pwd)/buildkite-cloudformation.json
KEY=${KEY:-default}
STACK=${STACK:-buildkite-$(date +%Y-%m-%d-%H-%M)}

echo "Generating $JSON_FILE"
cfoo $(dirname $0)/../buildkite-cloudformation.yml > $JSON_FILE
#trap "rm -f $JSON_FILE" EXIT

aws cloudformation create-stack \
  --stack-name $STACK \
  --template-body file://$JSON_FILE \
  --parameters \
    ParameterKey=KeyName,ParameterValue=$KEY