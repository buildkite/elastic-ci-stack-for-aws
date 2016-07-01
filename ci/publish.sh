#!/bin/bash

set -eu

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

wait_for_ami_to_be_available() {
  local image_id="$1"
  local region="$2"
  local image_state

  while true; do
    image_state=$(aws ec2 describe-images --region "$region" --image-ids "$image_id" --output text --query 'Images[*].State');
    echo "$image_id ($region) is $image_state"

    if [[ "$image_state" == "available" ]]; then
      break
    elif [[ "$image_state" == "pending" ]]; then
      sleep 5
    else
      exit 1
    fi
  done
}

make_ami_public() {
  local image_id="$1"
  local region="$2"
  local image_state

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

copy_ami_and_create_mappings_yml() {
  local base_image_id="$1"
  local destination_yml="$2"
  local image_name
  local region
  local copied_image_id

  image_name=$(fetch_ami_name "$base_image_id" us-east-1)

  cat << EOF > "$destination_yml"
Mappings:
  AWSRegion2AMI:
    us-east-1 : { AMI: $base_image_id }
EOF

  if [[ $BUILDKITE_BRANCH == "master" ]] ; then
    for region in ${DESTINATION_REGIONS[*]} ; do
      echo "--- Copying $image_id to $region"

      copied_image_id=$(copy_ami_to_region "$base_image_id" us-east-1 "$region" "$image_name-$region")

      wait_for_ami_to_be_available "$copied_image_id" "$region"

      make_ami_public "$copied_image_id" "$region"

      echo "    $region : { AMI: $copied_image_id }" >> "$destination_yml"
    done
  fi
}

generate_mappings() {
  local image_id
  local s3_mappings_cache

  image_id=$(buildkite-agent meta-data get image_id)
  s3_mappings_cache="s3://${BUILDKITE_AWS_STACK_BUCKET}/mappings-${image_id}.yml"

  if aws s3 cp "${s3_mappings_cache}" templates/mappings.yml ; then
    echo "Skipping creating additional AZ mappings, base AMI has not changed"
  else
    copy_ami_and_create_mappings_yml "$image_id" templates/mappings.yml

    aws s3 cp templates/mappings.yml "${s3_mappings_cache}"
  fi
}

echo "--- Generating mappings"

generate_mappings

echo "--- Building and publishing stack"

make setup build

if [[ $BUILDKITE_BRANCH == "master" ]] ; then
  aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
  aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"
fi

aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/mappings.yml"
aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/${BUILDKITE_BRANCH}/aws-stack.json"