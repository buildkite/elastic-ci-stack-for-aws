#!/bin/bash
set -eu

image_id=$(buildkite-agent meta-data get image_id)

echo "Publishing branch $BUILDKITE_BRANCH"

cat << EOF > templates/mappings.yml
Mappings:
  AWSRegion2AMI:
    us-east-1     : { AMI: $image_id }
EOF

make setup build

if [[ $BUILDKITE_BRANCH == "master" ]] ; then
	aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
	aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"
fi

aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/mappings.yml"
aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/aws-stack.json"