#!/bin/bash
set -euo pipefail

mkdir -p build

# Update buildkite-ami first so it can be captured in packer_files_sha
make buildkite-ami.json

packer_files_sha=$(find packer/ plugins/ -type f -print0 | xargs -0 sha1sum | awk '{print $1}' | sort | sha1sum | awk '{print $1}')
echo "Packer files hash is $packer_files_sha"

stable_agent_sha=$(curl -Lfs https://download.buildkite.com/agent/stable/latest/buildkite-agent-linux-amd64.sha256)
echo "Agent stable sha256 is $stable_agent_sha"

unstable_agent_sha=$(curl -Lfs https://download.buildkite.com/agent/unstable/latest/buildkite-agent-linux-amd64.sha256)
echo "Agent unstable sha256 is $unstable_agent_sha"

packer_hash=$(echo "$packer_files_sha" "$stable_agent_sha" "$unstable_agent_sha" | sha1sum | awk '{print $1}')
echo "Packer image hash is $packer_hash"

packer_file="${packer_hash}.packer"

if ! aws s3 cp "s3://${BUILDKITE_STACK_BUCKET}/${packer_file}" . ; then
  make build-ami | tee "$packer_file"
  aws s3 cp "${packer_file}" "s3://${BUILDKITE_STACK_BUCKET}/${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

image_id=$(grep -Eo "${AWS_DEFAULT_REGION}: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for ${AWS_DEFAULT_REGION} is $image_id"

buildkite-agent meta-data set image_id "$image_id"
