#!/bin/bash
set -euo pipefail

mkdir -p build

buildkite-agent artifact download "build/buildkite-lifecycle-agent" build/

packer_files_sha=$(find packer/ -type f -print0 | xargs -0 sha1sum | awk '{print $1}' | sort | sha1sum | awk '{print $1}')
echo "Packer files hash is $packer_files_sha"

agent_version_sha=$(curl -f -s https://api.github.com/repos/buildkite/agent/releases/latest | grep -Eo '"tag_name": "(.+)"' | sha1sum | awk '{print $1}')
echo "Agent version hash is $agent_version_sha"

packer_hash=$(echo "$packer_files_sha" "$agent_version_sha" | sha1sum | awk '{print $1}')
echo "Packer image hash is $packer_hash"

packer_file="${packer_hash}.packer"

if ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  make build-ami | tee "$packer_file"
  aws s3 cp "${packer_file}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

image_id=$(grep -Eo "us-east-1: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for us-east-1 is $image_id"

buildkite-agent meta-data set image_id "$image_id"