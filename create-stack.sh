#!/bin/bash -euo pipefail

build_parameters() {
  for k in "$@" ; do
    printf "ParameterKey=%s,ParameterValue=%s " ${k%=*} ${k#*=}
  done
}

if [[ $# -lt 3 ]] ; then
  echo "usage: $0 <org-slug> <api-token> <agent-token> [... Key=Val]"
  exit 1
fi

ORG_SLUG=$1
API_TOKEN=$2
AGENT_TOKEN=$3
shift 3

STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
STACK_TEMPLATE="$(dirname $0)/cloudformation.json"
PROVISION_BUCKET=${PROVISION_BUCKET:-${ORG_SLUG}-buildkite}

cd $(dirname $0)
make all

PARAMS=$(build_parameters "$@")
PARAMS+=" ParameterKey=ProvisionBucket,ParameterValue=$PROVISION_BUCKET"
PARAMS+=" ParameterKey=BuildkiteOrgSlug,ParameterValue=$ORG_SLUG"
PARAMS+=" ParameterKey=BuildkiteApiToken,ParameterValue=$API_TOKEN"
PARAMS+=" ParameterKey=BuildkiteAgentToken,ParameterValue=$AGENT_TOKEN"

# http://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html
echo "Creating cfn stack ${STACK_NAME}"
aws cloudformation create-stack \
  --stack-name ${STACK_NAME} \
  --disable-rollback \
  --template-body "file://${STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM \
  --parameters $PARAMS
