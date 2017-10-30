#!/bin/bash
set -eu

is_tag_build() {
  [[ "$BUILDKITE_TAG" = "$BUILDKITE_BRANCH" ]]
}

is_latest_tag() {
  [[ "$BUILDKITE_TAG" = $(git describe --abbrev=0 --tags --match 'v*') ]]
}

is_release_candidate_tag() {
  [[ "$BUILDKITE_TAG" =~ -rc ]]
}

s3_upload_templates() {
  local bucket_prefix="${1:-}"

  aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/${bucket_prefix}mappings.yml"
  aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/${bucket_prefix}aws-stack.json"
  aws s3 cp --acl public-read build/aws-stack.yml "s3://buildkite-aws-stack/${bucket_prefix}aws-stack.yml"

  echo "Published https://s3.amazonaws.com/buildkite-aws-stack/${bucket_prefix}mappings.yml"
  echo "Published https://s3.amazonaws.com/buildkite-aws-stack/${bucket_prefix}aws-stack.json"
  echo "Published https://s3.amazonaws.com/buildkite-aws-stack/${bucket_prefix}aws-stack.yml"
}

git fetch --tags
make clean

# Publish the top-level mappings only on when we see the most recent tag on master
if is_latest_tag ; then
  if ! is_release_candidate_tag ; then
    s3_upload_templates "latest/"
  fi
  s3_upload_templates
else
  echo "Skipping publishing latest, '$BUILDKITE_TAG' doesn't match '$(git describe origin/master --tags --match='v*')'"
fi

# Publish the most recent commit from each branch
s3_upload_templates "${BUILDKITE_BRANCH}/"

# Publish each build to a unique URL, to let people roll back to old versions
s3_upload_templates "${BUILDKITE_BRANCH}/${BUILDKITE_COMMIT}."
