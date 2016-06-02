#!/bin/bash
set -euo pipefail

mkdir -p build
buildkite-agent artifact download "build/buildkite-lifecycle-agent" build/

packer_files_sha=$(find packer/ -type f -print0 | xargs -0 sha1sum | awk '{print $1}' | sort | sha1sum | awk '{print $1}')
echo "Packer files hash is $packer_files_sha"

stable_agent_sha=$(curl -f https://download.buildkite.com/agent/stable/latest/buildkite-agent-linux-amd64.sha256)
echo "Agent stable sha256 is $stable_agent_sha"

unstable_agent_sha=$(curl -Lf https://download.buildkite.com/agent/unstable/latest/buildkite-agent-linux-amd64.sha256)
echo "Agent unstable sha256 is $stable_agent_sha"

experimental_agent_sha=$(curl -Lf https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-amd64.sha256)
echo "Agent experimental sha256 is $stable_agent_sha"

packer_hash=$(echo "$packer_files_sha" "$stable_agent_sha" "$unstable_agent_sha" "$experimental_agent_sha" | sha1sum | awk '{print $1}')
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