#!/bin/bash
set -eu

packer_hash=$(find packer -type f -print0 | xargs -0 sha1sum | cut -b-40 | sort | sha1sum | awk '{print $1}')
packer_file="${packer_hash}.packer"

if ! aws s3 cp "s3://${BUILDKITE_AWS_STACK_BUCKET}/${packer_file}" . ; then
  echo "Failed to find the image id that was built"
  exit 1
fi

image_id=$(grep -Eo "us-east-1: (ami-.+)$" "$packer_file" | awk '{print $2}')
echo "Using AMI $image_id (via $packer_file)"

cat << EOF > templates/mappings.yml
Mappings:
  AWSRegion2AMI:
    us-east-1     : { AMI: $image_id }
EOF

make build
aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"