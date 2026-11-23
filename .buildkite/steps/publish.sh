#!/bin/bash
set -euo pipefail

s3_upload_templates() {
  local bucket_prefix="${1:-}"

  aws s3 cp --content-type 'text/yaml' build/mappings.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}mappings.yml"
  aws s3 cp --content-type 'text/yaml' build/aws-stack.yml "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}aws-stack.yml"
}

# The security fixes only feed release notes, so a failed copy must not stop publishing.
s3_upload_security_fixes() {
  local bucket_prefix="$1"

  local security_fixes
  for security_fixes in build/security-fixes-*.txt; do
    [[ -e "$security_fixes" ]] || continue
    # Served as text, so the link in the release notes opens in a browser.
    aws s3 cp --content-type 'text/plain; charset=utf-8' "$security_fixes" "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${bucket_prefix}$(basename "$security_fixes")" \
      || echo "WARNING: could not publish ${security_fixes} to ${bucket_prefix}"
  done
}

# Publishes the page release notes link for the fixes that are new since the previous
# release. The notes are written before this build runs, so the link must not be left dead.
s3_upload_new_security_fixes() {
  local name="$1"

  compgen -G "build/security-fixes-*.txt" >/dev/null || return
  local previous_tag
  previous_tag="$(git describe --tags --abbrev=0 --match='v*' --exclude="${BUILDKITE_TAG:-}" HEAD)" || return
  local bucket_url="https://s3.amazonaws.com/${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}"
  local page="build/security-fixes-linux-new.md"
  # Reads this build's files from where s3_upload_security_fixes has just put them.
  .buildkite/scripts/ami_security_notes.py --page --base-url "$bucket_url" "$previous_tag" "$name" >"$page" || return
  aws s3 cp --content-type 'text/plain; charset=utf-8' "$page" "s3://${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${name}/$(basename "$page")"
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

echo "--- Downloading AMI security fixes"
# Saved by the Linux test steps; absent when a build reuses the AMIs from main.
buildkite-agent artifact download "build/security-fixes-*.txt" build/ \
  || echo "No AMI security fixes in this build"

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

publish_for_branch() {
  local branch="$1"

  # Publish the most recent commit from each branch
  s3_upload_templates "${branch}/"

  # Publish each build to a unique URL, to let people roll back to old versions
  s3_upload_templates "${branch}/${BUILDKITE_COMMIT}."

  # Release notes read these by tag, so one copy per branch or tag is enough.
  s3_upload_security_fixes "${branch}/"
  if ! s3_upload_new_security_fixes "$branch"; then
    echo "Did not publish the page of new AMI security fixes for ${branch}"
    if [[ -n "${BUILDKITE_TAG:-}" ]]; then
      buildkite-agent annotate --style "warning" --context "security-fixes" \
        "This build did not publish the AMI security fixes for ${branch}. Remove the links to them from its release notes." \
        || true
    fi
  fi

  cat <<EOF | buildkite-agent annotate --style "info"
Published template <a href="https://s3.amazonaws.com/${BUILDKITE_AWS_STACK_TEMPLATE_BUCKET}/${branch}/aws-stack.yml">${branch}/aws-stack.yml</a>
EOF
}

# NOTE: in tag builds, $BUILDKITE_BRANCH == $BUILDKITE_TAG, so this will publish to the tag and exit
if [[ "$BUILDKITE_BRANCH" != "$BUILDKITE_PIPELINE_DEFAULT_BRANCH" ]]; then
  publish_for_branch "$BUILDKITE_BRANCH"

  exit 0
fi

# TODO: remove "master" from this list
default_branch_aliases=(master main)
for branch in "${default_branch_aliases[@]}"; do
  publish_for_branch "$branch"
done
