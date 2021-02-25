#!/bin/bash
set -euo pipefail

if [[ -z "${BUILDKITE_AWS_STACK_BUCKET}" ]] ; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_BUCKET for temporary files"
  exit 1
fi

os="${1:-linux}"
arch="${2:-amd64}"
agent_binary="buildkite-agent-${os}-${arch}"
s3secrets_binary="s3secrets-helper-${os}-${arch}"

if [[ "$os" == "windows" ]] ; then
  agent_binary+=".exe"
  s3secrets_binary+=".exe"
fi

mkdir -p "build/"

buildkite-agent artifact download "build/$s3secrets_binary" .

# Build a hash of packer files and the agent versions
packer_files_sha=$(find Makefile "packer/${os}" plugins/ -type f -print0 | xargs -0 sha1sum | awk '{print $1}' | sort | sha1sum | awk '{print $1}')
stable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/stable/latest/${agent_binary}.sha256")
unstable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/unstable/latest/${agent_binary}.sha256")
packer_hash=$(echo "$packer_files_sha" "$arch" "$stable_agent_sha" "$unstable_agent_sha" | sha1sum | awk '{print $1}')

echo "Packer image hash for ${os}/${arch} is ${packer_hash}"
packer_file="packer-${packer_hash}-${os}-${arch}.output"

# Only build packer image if one with the same hash doesn't exist, and we're not being forced
if [[ -n "${PACKER_REBUILD:-}" ]] || ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  make "packer-${os}-${arch}.output"
  aws s3 cp "packer-${os}-${arch}.output" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
  mv "packer-${os}-${arch}.output" "${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

# Get the image id from the packer build output for later steps
image_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for ${AWS_REGION} is $image_id"

buildkite-agent meta-data set "${os}_${arch}_image_id" "$image_id"
