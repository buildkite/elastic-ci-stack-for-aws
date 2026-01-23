#!/usr/bin/env bash
set -euo pipefail

echo "Pre-pulling Docker images into AMI..."

# ECR images to bake into the AMI
# Add your images here (one per line)
ECR_IMAGES=(
  "933102013064.dkr.ecr.us-west-2.amazonaws.com/applied_dev_uniified:v3.2.18"
)

# Authenticate to ECR (uses instance IAM role)
# Extract unique ECR registries from the image list
declare -A REGISTRIES
for IMAGE in "${ECR_IMAGES[@]}"; do
  if [[ "$IMAGE" == *.dkr.ecr.*.amazonaws.com/* ]]; then
    REGISTRY="${IMAGE%%/*}"
    REGION=$(echo "$REGISTRY" | sed 's/.*\.ecr\.\(.*\)\.amazonaws\.com/\1/')
    REGISTRIES["$REGISTRY"]="$REGION"
  fi
done

# Login to each unique ECR registry
for REGISTRY in "${!REGISTRIES[@]}"; do
  REGION="${REGISTRIES[$REGISTRY]}"
  echo "Authenticating to ECR registry: $REGISTRY (region: $REGION)"
  aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
done

# Pull each image
for IMAGE in "${ECR_IMAGES[@]}"; do
  echo "Pulling image: $IMAGE"
  docker pull "$IMAGE"
done

echo "Pre-pulled images:"
docker images

echo "Docker image pre-pull complete!"

