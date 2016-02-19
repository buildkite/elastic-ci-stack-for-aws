#!/bin/bash
set -eu

image_id=$(buildkite-agent meta-data get image_id)

cat << EOF > templates/mappings.yml
Mappings:
  AWSRegion2AMI:
    us-east-1     : { AMI: $image_id }
EOF

make setup build
aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"