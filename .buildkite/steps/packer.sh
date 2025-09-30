#!/bin/bash
set -euo pipefail

if [[ -z "${BUILDKITE_AWS_STACK_BUCKET}" ]]; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_BUCKET for temporary files"
  exit 1
fi

os="${1:-linux}"
arch="${2:-amd64}"
variant="${3:-stack}" # "stack" (default) or "base"

mkdir -p "build/"

# Generate timestamped output filenames
timestamp=$(date -u +"%Y%m%d-%H%M%S")
if [[ "${variant}" == "base" ]]; then
  packer_file="packer-base-${os}-${arch}-${timestamp}.output"
  local_output="packer-base-${os}-${arch}.output"
  make "packer-base-${os}-${arch}.output"
else
  # Get base AMI ID from metadata (set by base build step) or S3 fallback
  base_ami_id="$(buildkite-agent meta-data get "${os}-base-${arch}-ami" || true)"

  if [[ -z "$base_ami_id" ]]; then
    echo "Base AMI ID not found in metadata, checking S3 for latest base image..."

    # Try to fetch the latest base AMI output from S3
    latest_base_file="packer-base-${os}-${arch}-latest.output"
    if aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${latest_base_file}" "/tmp/${latest_base_file}" 2>/dev/null; then
      base_ami_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "/tmp/${latest_base_file}" | awk '{print $2}')
      echo "Found base AMI ID from S3: $base_ami_id"
      rm -f "/tmp/${latest_base_file}"
    fi
  fi

  if [[ -z "$base_ami_id" ]]; then
    echo "ERROR: No golden base AMI found for ${os}/${arch}. Ensure a base image has been built from main branch." >&2
    exit 1
  fi

  packer_file="packer-${os}-${arch}-${timestamp}.output"
  local_output="packer-${os}-${arch}.output"
  make "packer-${os}-${arch}.output" BASE_AMI_ID="$base_ami_id"
fi

# Upload to S3 with timestamped filename
aws s3 cp "${local_output}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"

# For base images on main branch, also upload as "latest"
if [[ "${variant}" == "base" && "${BUILDKITE_BRANCH:-}" == "main" ]]; then
  latest_file="packer-base-${os}-${arch}-latest.output"
  aws s3 cp "${local_output}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${latest_file}"
  echo "Updated latest base AMI pointer for ${os}/${arch}"
fi

mv "${local_output}" "${packer_file}"

# Get the image id from the packer build output for later steps
image_id=$(grep -Eo "${AWS_REGION}: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for ${AWS_REGION} is $image_id"

if [[ "${variant}" == "base" ]]; then
  buildkite-agent meta-data set "${os}-base-${arch}-ami" "$image_id"
else
  buildkite-agent meta-data set "${os}_${arch}_image_id" "$image_id"
fi
