#!/bin/bash
set -eu
set -o pipefail

cd $(dirname $0)/../packer/

packer_hash=$(find . -type f -print0 | xargs -0 sha1sum | cut -b-40 | sort | sha1sum | awk '{print $1}')
packer_file="${packer_hash}.packer"

echo "Packer image hash is $packer_hash"

if ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  packer validate buildkite-ami.json
  packer build buildkite-ami.json | tee "$packer_file"
  aws s3 cp "${packer_file}" "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}"
else
  echo "Skipping packer build, no changes"
fi

image_id=$(grep -Eo "us-east-1: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "AMI for us-east-1 is $image_id"

buildkite-agent meta-data set image_id "$image_id"