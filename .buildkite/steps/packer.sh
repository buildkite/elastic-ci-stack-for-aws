#!/bin/bash
set -euo pipefail

if [[ -z "${BUILDKITE_AWS_STACK_BUCKET}" ]]; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_BUCKET for temporary files"
  exit 1
fi

os="${1:-linux}"
arch="${2:-amd64}"
variant="${3:-full}" # "full" (default) or "base"
agent_binary="buildkite-agent-${os}-${arch}"

if [[ "$os" == "windows" ]]; then
  agent_binary+=".exe"
fi

mkdir -p "build/"

# Build a hash of packer files and the agent versions
packer_files_sha=$(find Makefile "packer/${os}" plugins/ -type f -print0 | xargs -0 sha256sum | awk '{print $1}' | sort | sha256sum | awk '{print $1}')
internal_files_sha=$(find go.mod go.sum internal/ -type f -print0 | xargs -0 sha256sum | awk '{print $1}' | sort | sha256sum | awk '{print $1}')
stable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/stable/latest/${agent_binary}.sha256")
unstable_agent_sha=$(curl -Lfs "https://download.buildkite.com/agent/unstable/latest/${agent_binary}.sha256")
packer_hash=$(echo "$packer_files_sha" "$internal_files_sha" "$arch" "$stable_agent_sha" "$unstable_agent_sha" "$variant" | sha256sum | awk '{print $1}')

# Include variant in the hash so base and full images don’t clash
echo "Packer image hash for ${os}/${arch} (${variant}) is ${packer_hash}"
if [[ "${variant}" == "base" ]]; then
  packer_file="packer-${packer_hash}-${os}-${arch}-base.output"
  local_output="packer-base-${os}-${arch}.output"
else
  packer_file="packer-${packer_hash}-${os}-${arch}.output"
  local_output="packer-${os}-${arch}.output"
fi

# Only build packer image if one with the same hash doesn't exist, and we're not being forced
if [[ -n "${PACKER_REBUILD:-}" ]] || ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" .; then
  if [[ "${variant}" == "base" ]]; then
    make "packer-base-${os}-${arch}.output"
  else
    # Require a golden base AMI. Try metadata first, then S3 as fallback.
    base_ami_id="$(buildkite-agent meta-data get "${os}-base-${arch}-ami" || true)"

    if [[ -z "$base_ami_id" ]]; then
      echo "Base AMI ID not found in metadata, checking S3 for latest base image..."

      # Calculate hash for base image to find the S3 file
      base_packer_hash=$(echo "$packer_files_sha" "$internal_files_sha" "$arch" "$stable_agent_sha" "$unstable_agent_sha" "base" | sha256sum | awk '{print $1}')
      base_packer_file="packer-${base_packer_hash}-${os}-${arch}-base.output"

      # Try to download and extract AMI ID from the base image packer output
      if aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${base_packer_file}" "/tmp/${base_packer_file}" 2>/dev/null; then
        base_ami_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "/tmp/${base_packer_file}" | awk '{print $2}')
        echo "Found base AMI ID from S3: $base_ami_id"
        rm -f "/tmp/${base_packer_file}"
      fi
    fi

    if [[ -z "$base_ami_id" ]]; then
      echo "ERROR: No golden base AMI found for ${os}/${arch}. Ensure the corresponding base image step ran and uploaded the AMI ID." >&2
      exit 1
    fi

    make "packer-${os}-${arch}.output" BASE_AMI_ID="$base_ami_id"
  fi
  aws s3 cp "${local_output}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
  mv "${local_output}" "${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

# Get the image id from the packer build output for later steps
image_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for ${AWS_REGION} is $image_id"

if [[ "${variant}" == "base" ]]; then
  buildkite-agent meta-data set "${os}-base-${arch}-ami" "$image_id"
else
  buildkite-agent meta-data set "${os}_${arch}_image_id" "$image_id"
fi
