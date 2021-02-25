#!/bin/bash
set -euo pipefail

# Copies an AMI to all other regions and outputs a build/mappings.yml file
# Local Usage: .buildkite/steps/copy.sh <linux_ami_id> <windows_ami_id>

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

get_image_name() {
  local image_id="$1"
  local region="$2"

  aws ec2 describe-images \
  --image-ids "$image_id" \
  --output text \
  --region "$region" \
  --query 'Images[*].Name'
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
  af-south-1
  ap-east-1
  ap-south-1
  ap-northeast-2
  ap-northeast-1
  ap-southeast-2
  ap-southeast-1
  ca-central-1
  eu-central-1
  eu-west-1
  eu-west-2
  eu-south-1
  eu-west-3
  eu-north-1
  me-south-1
  sa-east-1
)

IMAGES=(
)

# Configuration
linux_amd64_source_image_id="${1:-}"
linux_arm64_source_image_id="${1:-}"
windows_amd64_source_image_id="${2:-}"

source_region="${AWS_REGION}"
mapping_file="build/mappings.yml"

# Read the source images from meta-data if no arguments are provided
if [ $# -eq 0 ] ; then
    linux_amd64_source_image_id=$(buildkite-agent meta-data get "linux_amd64_image_id")
    linux_arm64_source_image_id=$(buildkite-agent meta-data get "linux_arm64_image_id")
    windows_amd64_source_image_id=$(buildkite-agent meta-data get "windows_amd64_image_id")
fi

# If we're not on the master branch or a tag build skip the copy
if [[ $BUILDKITE_BRANCH != "master" ]] && [[ "$BUILDKITE_TAG" != "$BUILDKITE_BRANCH" ]] ; then
  echo "--- Skipping AMI copy on non-master/tag branch " >&2
  mkdir -p "$(dirname "$mapping_file")"
  cat << EOF > "$mapping_file"
Mappings:
  AWSRegion2AMI:
    ${AWS_REGION} : { linuxamd64: $linux_amd64_source_image_id, linuxarm64: $linux_arm64_source_image_id, windows: $windows_amd64_source_image_id }
EOF
  exit 0
fi

s3_mappings_cache=$(printf "s3://%s/mappings-%s-%s-%s-%s.yml" \
  "${BUILDKITE_AWS_STACK_BUCKET}" \
  "${linux_amd64_source_image_id}" \
  "${linux_arm64_source_image_id}" \
  "${windows_amd64_source_image_id}" \
  "${BUILDKITE_BRANCH}")

# Check if there is a previously copy in the cache bucket
if aws s3 cp "${s3_mappings_cache}" "$mapping_file" ; then
  echo "--- Skipping AMI copy, was previously copied"
  exit 0
fi

# Get the image names to copy to other regions
linux_amd64_source_image_name=$(get_image_name "$linux_amd64_source_image_id" "$source_region")
linux_arm64_source_image_name=$(get_image_name "$linux_arm64_source_image_id" "$source_region")
windows_amd64_source_image_name=$(get_image_name "$windows_amd64_source_image_id" "$source_region")

# Copy to all other regions
for region in ${ALL_REGIONS[*]}; do
  if [[ $region != "$source_region" ]] ; then
    echo "--- :linux: Copying Linux AMD64 $linux_amd64_source_image_id to $region" >&2
    IMAGES+=("$(copy_ami_to_region "$linux_amd64_source_image_id" "$source_region" "$region" "${linux_amd64_source_image_name}-${region}")")

    echo "--- :linux: Copying Linux ARM64 $linux_arm64_source_image_id to $region" >&2
    IMAGES+=("$(copy_ami_to_region "$linux_arm64_source_image_id" "$source_region" "$region" "${linux_arm64_source_image_name}-${region}")")

    echo "--- :windows: Copying Windows AMD64 $windows_amd64_source_image_id to $region" >&2
    IMAGES+=("$(copy_ami_to_region "$windows_amd64_source_image_id" "$source_region" "$region" "${windows_amd64_source_image_name}-${region}")")
  else
    IMAGES+=("$linux_amd64_source_image_id" "$linux_arm64_source_image_id" "$windows_amd64_source_image_id")
  fi
done

# Write yaml preamble
mkdir -p "$(dirname "$mapping_file")"
cat << EOF > "$mapping_file"
Mappings:
  AWSRegion2AMI:
EOF

echo "--- Waiting for AMIs to become available"  >&2

for region in ${ALL_REGIONS[*]}; do
  linux_amd64_image_id="${IMAGES[0]}"
  linux_arm64_image_id="${IMAGES[1]}"
  windows_amd64_image_id="${IMAGES[2]}"

  wait_for_ami_to_be_available "$linux_amd64_image_id" "$region" >&2

  # Make the linux AMI public if it's not the source image
  if [[ $linux_amd64_image_id != "$linux_amd64_source_image_id" ]] ; then
    echo ":linux: Making Linux AMD64 ${linux_amd64_image_id} public" >&2
    make_ami_public "$linux_amd64_image_id" "$region"
  fi

  wait_for_ami_to_be_available "$linux_arm64_image_id" "$region" >&2

  # Make the linux ARM AMI public if it's not the source image
  if [[ $linux_arm64_image_id != "$linux_arm64_source_image_id" ]] ; then
    echo ":linux: Making Linux ARM64 ${linux_arm64_image_id} public" >&2
    make_ami_public "$linux_arm64_image_id" "$region"
  fi

  wait_for_ami_to_be_available "$windows_amd64_image_id" "$region" >&2

  # Make the windows AMI public if it's not the source image
  if [[ $windows_amd64_image_id != "$windows_amd64_source_image_id" ]] ; then
    echo ":windows: Making Windows AMD64 ${windows_amd64_image_id} public" >&2
    make_ami_public "$windows_amd64_image_id" "$region"
  fi

  # Write yaml to file
  echo "    $region : { linuxamd64: $linux_amd64_image_id, linuxarm64: $linux_arm64_image_id, windows: $windows_amd64_image_id }"  >> "$mapping_file"

  # Shift off the processed images
  IMAGES=("${IMAGES[@]:3}")
done

echo "--- Uploading mapping to s3 cache"
aws s3 cp "$mapping_file" "${s3_mappings_cache}"
