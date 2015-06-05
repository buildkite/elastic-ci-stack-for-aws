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

# grab the org slug to generate the provision bucket default
if [[ "$*" =~ BuildkiteOrgSlug=([0-9a-zA-Z_\-]+) ]]; then
  ORG_SLUG=${BASH_REMATCH[1]}
elif [[ -z $PROVISION_BUCKET ]]; then
  echo "Must provide either BuildkiteOrgSlug parameter or set a PROVISION_BUCKET env"
  exit 1
fi

PROVISION_BUCKET=${PROVISION_BUCKET:-${ORG_SLUG}-buildkite}
STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
STACK_TEMPLATE="$(dirname $0)/cloudformation.json"

cd $(dirname $0)
make all

PARAMS=$(build_parameters "$@")
PARAMS+=" ParameterKey=ProvisionBucket,ParameterValue=$PROVISION_BUCKET"

# http://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html
echo "Creating cfn stack ${STACK_NAME}"
aws cloudformation create-stack \
  --stack-name ${STACK_NAME} \
  --disable-rollback \
  --template-body "file://${STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM \
  --parameters $PARAMS
