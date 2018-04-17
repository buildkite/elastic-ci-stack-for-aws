#!/bin/bash
# shellcheck disable=SC1117
set -eu

inputPackerJsonFile="${1:-packer/buildkite-ami.json.example}"
outputPackerJsonFile="${2:-packer/buildkite-ami.json}"
configJson=$(cat "${inputPackerJsonFile}")

# use AWS_REGION if defined, if not use AWS_DEFAULT_REGION
awsRegion="${AWS_REGION:-}"
[ -z "${awsRegion:-}" ] \
  && awsRegion="${AWS_DEFAULT_REGION:-}"

[ ! -z "${awsRegion:-}" ] \
  && configJson=$(echo "${configJson}" | jq ".builders[0].region = \"${awsRegion}\"")

[ ! -z "${AWS_SOURCE_AMI_ID:-}" ] \
  && configJson=$(echo "${configJson}" | jq ".builders[0].source_ami = \"${AWS_SOURCE_AMI_ID}\"")

echo "$configJson" > "${outputPackerJsonFile}"
