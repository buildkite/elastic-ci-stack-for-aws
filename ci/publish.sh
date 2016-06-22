#!/bin/bash

set -eu

copy_ami_to_region() {
  local source_ami_id="$1"
  local source_region="$2"
  local destination_image_region="$3"
  local destination_image_name="$4"

  echo "Copying $source_ami_id to $destination_image_region..." >&2

  aws ec2 copy-image \
    --source-image-id "$source_ami_id" \
    --source-region "$source_region" \
    --name "$destination_image_name" \
    --region "$destination_image_region" \
    --query "ImageId" \
    --output text
}

make_ami_public() {
  local image_id="$1"
  local region="$2"

  aws ec2 modify-image-attribute --region "$region" --image-id "$image_id" --launch-permission "{\"Add\": [{\"Group\":\"all\"}]}"
}

fetch_ami_name() {
  local ami_id="$1"
  local region="$2"

  echo "Fetching ami name for $ami_id..." >&2

  aws ec2 describe-images \
    --image-ids "$ami_id" \
    --region "$region" \
    --output text \
    --query 'Images[*].Name'
}

DESTINATION_REGIONS=(
  us-west-1
  us-west-2
  eu-west-1
  eu-central-1
  ap-northeast-1
  ap-northeast-2
  ap-southeast-1
  ap-southeast-2
  sa-east-1
)

image_id=$(buildkite-agent meta-data get image_id)
image_name=$(fetch_ami_name "$image_id" us-east-1)

echo "--- Creating mappings.yml"

cat << EOF > templates/mappings.yml
Mappings:
  AWSRegion2AMI:
    us-east-1 : { AMI: $image_id }
EOF

for region in ${DESTINATION_REGIONS[*]} ; do
  copied_image_id=$(copy_ami_to_region "$image_id" us-east-1 "$region" "$image_name-$region")

  make_ami_public "$copied_image_id" "$region"

  echo "    $region : { AMI: $copied_image_id }" >> templates/mappings.yml
done

echo "--- Building and publishing stack"

make setup build

if [[ $BUILDKITE_BRANCH == "master" ]] ; then
  aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
  aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"
fi

aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/mappings.yml"
aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/aws-stack.json"