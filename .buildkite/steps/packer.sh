#!/bin/bash
set -euo pipefail

if [[ -z "${BUILDKITE_AWS_STACK_BUCKET}" ]] ; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_BUCKET for temporary files"
  exit 1
fi

os="${1:-linux}"
build_dir="build/${os}"

mkdir -p "${build_dir}"

# Build a hash of packer files and the agent versions
packer_files_sha=$(find "packer/${os}" plugins/ -type f -print0 | xargs -0 sha1sum | awk '{print $1}' | sort | sha1sum | awk '{print $1}')
stable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/stable/latest/buildkite-agent-${os}-amd64.sha256")
unstable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/unstable/latest/buildkite-agent-${os}-amd64.sha256")
packer_hash=$(echo "$packer_files_sha" "$stable_agent_sha" "$unstable_agent_sha" | sha1sum | awk '{print $1}')

echo "Packer image hash for ${os} is ${packer_hash}"
packer_file="${packer_hash}.packer"

# Only build packer image if one with the same hash doesn't exist
if ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  make packer
  aws s3 cp packer.output "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
  mv packer.output "${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

# Get the image id from the packer build output for later steps
image_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for ${AWS_REGION} is $image_id"

buildkite-agent meta-data set image_id "$image_id"
