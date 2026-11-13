#!/bin/bash
set -euo pipefail

s3_upload_templates() {
  local bucket_prefix="${1:-}"

  aws s3 cp --content-type 'text/yaml' build/mappings.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}mappings.yml"
  aws s3 cp --content-type 'text/yaml' build/aws-stack.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}aws-stack.yml"
}

echo "--- :git: Checking and fetching git tags"
# if BUILDKITE_TAG is set, fetch the tags, and check that it's a valid tag
if [[ -n "${BUILDKITE_TAG:-}" ]]; then
  git fetch -v --tags
  if ! git tag --list | grep -q "^${BUILDKITE_TAG}$"; then
    echo "^^^ +++"
    echo "Tag ${BUILDKITE_TAG} does not exist"
    exit 1
  fi
else
  echo "Not a tag build, skipping tag check"
fi

echo "--- :aws: Checking template bucket is set"
if [[ -z "${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}" ]]; then
  echo "^^^ +++"
  echo "Must set an s3 bucket in BUILDKITE_AWS_STACK_TEMPLATE_BUCKET for publishing templates to"
  exit 1
fi

echo "--- Downloading mappings.yml artifact"
mkdir -p build/
buildkite-agent artifact download build/mappings.yml build/

echo "--- Building :cloudformation: CloudFormation templates"
make build/aws-stack.yml

echo "--- Uploading :cloudformation: CloudFormation templates"
trunk="origin/${BUILDKITE_PIPELINE_DEFAULT_BRANCH}"
latest_tag="$(git describe --tags --abbrev=0 --match='v*' "$trunk")"
# Pre-release tags are those that have a hyphen in them, e.g. v1.0.0-rc1
latest_stable_tag="$(git describe --tags --abbrev=0 --match='v*' --exclude='*-*' "$trunk")"

# Only publish to 'latest' (and the empty prefix) if this tag is the latest stable tag.
if [[ "${BUILDKITE_TAG}" == "${latest_stable_tag}" ]]; then
  s3_upload_templates "latest/"
  s3_upload_templates
elif [[ "${BUILDKITE_TAG}" == "${latest_tag}" ]]; then
  echo "Skipping publishing latest, although ${BUILDKITE_TAG} matches ${latest_tag} it does not doesn't match ${latest_stable_tag}"
else
  echo "Skipping publishing latest, $BUILDKITE_TAG doesn't match $latest_tag"
fi

verify_release_templates() {
  echo "--- :mag: Verifying published ${BUILDKITE_TAG} templates"
  local file
  for file in aws-stack.yml mappings.yml; do
    # Anonymous HTTPS also proves the objects are public.
    curl --fail --silent --show-error \
      "https://s3.amazonaws.com/${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${BUILDKITE_TAG}/${file}" \
      | cmp - "build/${file}"
  done

  grep -Fqx "Description: \"Buildkite stack ${BUILDKITE_TAG}\"" build/aws-stack.yml

  # Each region maps all five image variants, and the AMIs reached more than
  # the build region.
  awk '
    / : \{/ {
      regions++
      if (gsub(/ami-[0-9a-f]+/, "&") != 5) { print "Incomplete mapping: " $0; bad = 1 }
    }
    END { if (regions < 2) { print "Mappings cover " regions + 0 " region(s)"; bad = 1 }; exit bad }
  ' build/mappings.yml
}

publish_for_branch() {
  local branch="$1"

  # Publish the most recent commit from each branch
  s3_upload_templates "${branch}/"

  # Publish each build to a unique URL, to let people roll back to old versions
  s3_upload_templates "${branch}/${BUILDKITE_COMMIT}."

  cat <<EOF | buildkite-agent annotate --style "info"
Published template <a href="https://s3.amazonaws.com/${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${branch}/aws-stack.yml">${branch}/aws-stack.yml</a>
EOF
}

# NOTE: in tag builds, $BUILDKITE_BRANCH == $BUILDKITE_TAG, so this will publish to the tag and exit
if [[ "$BUILDKITE_BRANCH" != "$BUILDKITE_PIPELINE_DEFAULT_BRANCH" ]]; then
  publish_for_branch "$BUILDKITE_BRANCH"
  if [[ -n "${BUILDKITE_TAG:-}" ]]; then
    verify_release_templates
  fi

  exit 0
fi

# TODO: remove "master" from this list
default_branch_aliases=(master main)
for branch in "${default_branch_aliases[@]}"; do
  publish_for_branch "$branch"
done
