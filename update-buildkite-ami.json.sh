#!/bin/bash
# shellcheck disable=SC1117
set -eu

inputPackerJsonFile="${1:-packer/buildkite-ami.json.example}"
outputPackerJsonFile="${2:-packer/buildkite-ami.json}"
configJson=$(cat "${inputPackerJsonFile}")
[ ! -z "${AWS_DEFAULT_REGION:-}" ] \
  && configJson=$(echo "${configJson}" | jq ".builders[0].region = \"${AWS_DEFAULT_REGION}\"")

[ ! -z "${AWS_REGION:-}" ] \
  && configJson=$(echo "${configJson}" | jq ".builders[0].region = \"${AWS_REGION}\"")

[ ! -z "${AWS_SOURCE_AMI_ID:-}" ] \
  && configJson=$(echo "${configJson}" | jq ".builders[0].source_ami = \"${AWS_SOURCE_AMI_ID}\"")

echo "$configJson" > "${outputPackerJsonFile}"
