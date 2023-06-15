#!/bin/bash
set -euo pipefail

is_latest_tag() {
  [[ "$BUILDKITE_TAG" = $(git describe --abbrev=0 --tags --match 'v*') ]]
}

is_prerelease_tag() {
  [[ "$BUILDKITE_TAG" =~ - ]]
}

s3_upload_templates() {
  local bucket_prefix="${1:-}"

  aws s3 cp --content-type 'text/yaml' --acl public-read build/mappings.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}mappings.yml"
  aws s3 cp --content-type 'text/yaml' --acl public-read build/aws-stack.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}aws-stack.yml"
}

if [[ -z "${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}" ]] ; then
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_TEMPLATE_BUCKET for publishing templates to"
  exit 1
fi

echo "--- Downloading mappings.yml artifact"
mkdir -p build/
buildkite-agent artifact download build/mappings.yml build/

echo "--- Fetching latest git tags"
git fetch --tags

echo "--- Building :cloudformation: CloudFormation templates"
make build/aws-stack.yml

echo "--- Uploading :cloudformation: CloudFormation templates"

# Publish the top-level mappings only on when we see the most recent tag on master
if is_latest_tag ; then
  if ! is_prerelease_tag ; then
    s3_upload_templates "latest/"
  fi
  s3_upload_templates
else
  echo "Skipping publishing latest, '$BUILDKITE_TAG' doesn't match '$(git describe origin/master --tags --match='v*')'"
fi

publish_for_branch() {
  local branch="$1"

  # Publish the most recent commit from each branch
  s3_upload_templates "${branch}/"

  # Publish each build to a unique URL, to let people roll back to old versions
  s3_upload_templates "${branch}/${BUILDKITE_COMMIT}."

  cat << EOF | buildkite-agent annotate --style "info"
Published template <a href="https://s3.amazonaws.com/${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${branch}/aws-stack.yml">${branch}/aws-stack.yml</a>
EOF
}

if [[ "$BUILDKITE_BRANCH" != "$BUILDKITE_PIPELINE_DEFAULT_BRANCH" ]]; then
  publish_for_branch "$BUILDKITE_BRANCH"

  exit 0
fi

# TODO: remove "master" from this list
default_branch_aliases=(master main)
for branch in "${default_branch_aliases[@]}"; do
  publish_for_branch "$branch"
done
