#!/bin/bash
set -euo pipefail

# Copies an AMI to all other regions and outputs a build/mappings.yml file
# Local Usage: .buildkite/steps/copy.sh <ami_id>

copy_ami_to_region() {
  local source_image_id="$1"
  local source_region="$2"
  local destination_image_region="$3"
  local destination_image_name="$4"

  aws ec2 copy-image \
    --source-image-id "$source_image_id" \
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
      sleep 10
    else
      exit 1
    fi
  done
}

make_ami_public() {
  local image_id="$1"
  local region="$2"

  aws ec2 modify-image-attribute \
    --region "$region" \
    --image-id "$image_id" \
    --launch-permission "{\"Add\": [{\"Group\":\"all\"}]}"
}

if [[ -z "${BUILDKITE_AWS_STACK_BUCKET}" ]] ; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_BUCKET for temporary files"
  exit 1
fi

ALL_REGIONS=(
  us-east-1
  us-east-2
  us-west-1
  us-west-2
  eu-west-1
  eu-west-2
  eu-central-1
  ap-northeast-1
  ap-northeast-2
  ap-southeast-1
  ap-southeast-2
  ap-south-1
  sa-east-1
)

IMAGES=(
)

# Configuration
source_image_id="${1:-}"
source_region="${AWS_REGION}"
mapping_file="build/mappings.yml"

# Read the source_image_id from meta-data if empty
if [[ -z "$source_image_id" ]] ; then
  source_image_id=$(buildkite-agent meta-data get image_id)
fi

# If we're not on the master branch or a tag build skip the copy
if [[ $BUILDKITE_BRANCH != "master" ]] && [[ "$BUILDKITE_TAG" != "$BUILDKITE_BRANCH" ]] ; then
  echo "--- Skipping AMI copy on non-master/tag branch " >&2
  mkdir -p "$(dirname "$mapping_file")"
  cat << EOF > "$mapping_file"
Mappings:
  AWSRegion2AMI:
    ${AWS_REGION} : { AMI: $source_image_id }
EOF
  exit 0
fi

s3_mappings_cache="s3://${BUILDKITE_AWS_STACK_BUCKET}/mappings-${source_image_id}-${BUILDKITE_BRANCH}.yml"

# Check if there is a previously copy in the cache bucket
if aws s3 cp "${s3_mappings_cache}" "$mapping_file" ; then
  echo "--- Skipping AMI copy, was previously copied"
  exit 0
fi

# Get the image name to copy to other amis
source_image_name=$(aws ec2 describe-images \
  --image-ids "$source_image_id" \
  --output text \
  --region "$source_region" \
  --query 'Images[*].Name')

# Copy to all other regions
for region in ${ALL_REGIONS[*]}; do
  if [[ $region != "$source_region" ]] ; then
    echo "--- Copying $source_image_id to $region" >&2
    IMAGES+=("$(copy_ami_to_region "$source_image_id" "$source_region" "$region" "${source_image_name}-${region}")")
  else
    IMAGES+=("$source_image_id")
  fi
done

# Write yaml preamble
cat << EOF > "$mapping_file"
Mappings:
  AWSRegion2AMI:
EOF

echo "--- Waiting for AMIs to become available"  >&2
for ((i=0; i<${#IMAGES[*]}; i++)); do
  region="${ALL_REGIONS[i]}"
  image_id="${IMAGES[i]}"

  wait_for_ami_to_be_available "$image_id" "$region" >&2

  # Make the AMI public if it's not the source image
  if [[ $image_id != "$source_image_id" ]] ; then
    echo "Making ${image_id} public" >&2
    make_ami_public "$image_id" "$region"
  fi

  # Write yaml to file
  echo "    $region : { AMI: $image_id }"  >> "$mapping_file"
done

echo "--- Uploading mapping to s3 cache"
aws s3 cp "$mapping_file" "${s3_mappings_cache}"
