#!/bin/bash -euo pipefail

## Uploads a tarball of the provision scripts and launches a CloudFormation stack

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

KEY_PAIR=${KEY_PAIR:-default}
STACK_NAME=${STACK_NAME:-buildkite-$(date +%Y-%m-%d-%H-%M)}
STACK_TEMPLATE="$(dirname $0)/cloudformation.json"
PROVISION_BUCKET=${PROVISION_BUCKET:-${ORG_SLUG}-buildkite}
PROVISION_DIR="$(dirname $0)/provision"

PARAMS=$(build_parameters "$@")
cd $(dirname $0)

if ! make ; then
  rm cloudformation.json
  echo "Failed to generate cloudformation template"
  exit 1
fi

echo "Building provision tarball from $PROVISION_DIR"
tar -zcf provision.tar.gz -C $PROVISION_DIR .
trap "rm provision.tar.gz" EXIT

PROVISION_FILE="provision-$(md5 -q provision.tar.gz).tar.gz"
PARAMS+=" ParameterKey=ProvisionBucket,ParameterValue=$PROVISION_BUCKET"
PARAMS+=" ParameterKey=ProvisionTarball,ParameterValue=$PROVISION_FILE"
PARAMS+=" ParameterKey=BuildkiteOrgSlug,ParameterValue=$ORG_SLUG"
PARAMS+=" ParameterKey=BuildkiteApiToken,ParameterValue=$API_TOKEN"
PARAMS+=" ParameterKey=BuildkiteAgentToken,ParameterValue=$AGENT_TOKEN"

# http://docs.aws.amazon.com/cli/latest/reference/s3api/put-object.html
echo "Uploading to s3://$PROVISION_BUCKET/$PROVISION_FILE"
aws s3api put-object \
  --bucket "$PROVISION_BUCKET" \
  --key "$PROVISION_FILE" \
  --body "provision.tar.gz"

if [ -n "$PARAMS" ]
then
  PARAMS="--parameters $PARAMS"
fi

# http://docs.aws.amazon.com/cli/latest/reference/cloudformation/create-stack.html
echo "Creating cfn stack ${STACK_NAME}"
aws cloudformation create-stack \
  --stack-name ${STACK_NAME} \
  --disable-rollback \
  --template-body "file://${STACK_TEMPLATE}" \
  --capabilities CAPABILITY_IAM \
  $PARAMS
