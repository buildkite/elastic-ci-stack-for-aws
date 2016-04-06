#!/bin/bash
set -euo pipefail

packer_hash=$(find packer/ -type f -print0 | xargs -0 sha1sum | cut -b-40 | sort | sha1sum | awk '{print $1}')
packer_file="${packer_hash}.packer"

echo "Packer image hash is $packer_hash"

if ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  make build-ami | tee "$packer_file"
  aws s3 cp "${packer_file}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

image_id=$(grep -Eo "us-east-1: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for us-east-1 is $image_id"

buildkite-agent meta-data set image_id "$image_id"