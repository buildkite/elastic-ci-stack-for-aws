#!/bin/bash -euo pipefail

build_parameters() {
  for k in "$@" ; do
    key=$(echo $k | cut -f1 -d=)
    value=${k#*$key=}
    printf "ParameterKey=%s,ParameterValue=%s " $key ${value//,/\\,}
  done
}

if [[ $# -lt 3 ]] ; then
  echo "usage: $0 [... Key=Val]"
  exit 1
fi

if [[ ! "$*" =~ BuildkiteOrgSlug=([0-9a-zA-Z_\-]+) ]]; then
  echo "Must provide a BuildkiteOrgSlug parameter"
  exit 1
fi

STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
STACK_TEMPLATE="$(dirname $0)/build/cloudformation.json"

cd $(dirname $0)
make all > /dev/null

# sometimes cfoo returns success but errors
if [[ ! -s $STACK_TEMPLATE ]] ; then
  echo $STACK_TEMPLATE is empty
  exit 1
fi

PARAMS=$(build_parameters "$@")

echo ">> Creating stack $STACK_NAME from $STACK_TEMPLATE"

# http://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html
stack_id=$(aws cloudformation create-stack \
  --output text \
  --stack-name ${STACK_NAME} \
  --disable-rollback \
  --template-body "file://${STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM \
  --parameters $PARAMS)

echo -e "\033[33;32m$stack_id\033[0m\n"

