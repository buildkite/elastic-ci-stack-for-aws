#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 <RELEASE_TAG> [PREVIOUS_TAG]"
  echo "Example: $0 v5.5.0"
  exit 1
fi

RELEASE_VERSION=$1
RELEASE_COMMIT=$(git rev-parse --verify "refs/tags/${RELEASE_VERSION}^{commit}")
RELEASE_LINE=${RELEASE_VERSION%%.*}

# 1. Bound the notes to release tags, even on a newer documentation branch.
PREVIOUS_TAG=${2:-$(git describe --tags --abbrev=0 --match="${RELEASE_LINE}.*" --exclude="$RELEASE_VERSION" "$RELEASE_COMMIT")}
PREVIOUS_COMMIT=$(git rev-parse --verify "refs/tags/${PREVIOUS_TAG}^{commit}")
if [[ "${PREVIOUS_TAG%%.*}" != "$RELEASE_LINE" || "$PREVIOUS_TAG" == "$RELEASE_VERSION" ]] \
  || ! git merge-base --is-ancestor "$PREVIOUS_COMMIT" "$RELEASE_COMMIT"; then
  echo "Previous tag must be distinct, on the same release line, and ancestral to the release" >&2
  exit 1
fi
if grep -Fq "## [${RELEASE_VERSION}](" CHANGELOG.md; then
  echo "CHANGELOG.md already contains ${RELEASE_VERSION}; review the existing entry instead" >&2
  exit 1
fi

# 2. GitHub's read-only preview includes squash-merged PRs that ghch omits.
# .github/release.yml groups its entries and leaves out changelog PRs. Keep its
# category headings and rewrite its bullets in this file's style.
echo "--- Generating changelog from ${PREVIOUS_TAG} to ${RELEASE_VERSION}"
RELEASE_NOTES=$(gh api --method POST repos/buildkite/elastic-ci-stack-for-aws/releases/generate-notes \
  -f tag_name="$RELEASE_VERSION" \
  -f target_commitish="$RELEASE_COMMIT" \
  -f previous_tag_name="$PREVIOUS_TAG" --jq .body \
  | tr -d '\r' \
  | awk '
      /^## New Contributors$/ { exit }
      /^<!--/ || /^## What.s Changed$/ || /^\*\*Full Changelog\*\*/ { next }
      { print }' \
  | sed -E 's|^\* (.+) by @([^ ]+) in (https://github\.com/[^ ]+/pull/([0-9]+))$|- \1 [#\4](\3) (@\2)|' \
  | sed -e '/./,$!d')
# The tag records when the release was cut; the target commit can be days older.
RELEASE_DATE=$(git for-each-ref --format='%(taggerdate:short)' "refs/tags/${RELEASE_VERSION}")
RELEASE_DATE=${RELEASE_DATE:-$(date -u +%F)}
CHANGELOG_BODY=$(printf '## [%s](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/%s) (%s)\n[Full Changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/compare/%s...%s)\n\n%s' \
  "$RELEASE_VERSION" "$RELEASE_VERSION" "$RELEASE_DATE" "$PREVIOUS_TAG" "$RELEASE_VERSION" "$RELEASE_NOTES")

# 3. Check for Buildkite Agent updates
AGENT_INSTALL_SCRIPT_LINUX="packer/linux/stack/scripts/install-buildkite-agent.sh"

extract_agent_version() {
  # Reads the pinned agent version from a given git ref's Linux install script.
  git show "$1:${AGENT_INSTALL_SCRIPT_LINUX}" 2>/dev/null | grep "AGENT_VERSION=" | cut -d'=' -f2 | tr -d '"'
}

PREVIOUS_AGENT_VERSION=$(extract_agent_version "$PREVIOUS_TAG")
CURRENT_AGENT_VERSION=$(extract_agent_version "$RELEASE_COMMIT")

if [[ "$PREVIOUS_AGENT_VERSION" != "$CURRENT_AGENT_VERSION" ]]; then
  echo "--- Buildkite Agent version has changed. Fetching agent release notes."

  # The stack can jump across multiple agent releases between two stack releases
  # (e.g. v3.128.0 -> v3.129.0 -> v3.130.0). Enumerate every stable agent release
  # in the range (PREVIOUS_AGENT_VERSION, CURRENT_AGENT_VERSION] so no hop is skipped.
  # Prereleases are available as the stack's beta variant, but are not the pinned agent.
  AGENT_VERSIONS=$(gh api --paginate 'repos/buildkite/agent/releases?per_page=100' \
    --jq '.[] | select(.prerelease == false and .draft == false) | .tag_name' \
    | sed 's/^v//' \
    | sort -V \
    | awk -v prev="$PREVIOUS_AGENT_VERSION" -v cur="$CURRENT_AGENT_VERSION" '
        $0 == prev { seen = 1; next }
        seen { print }
        $0 == cur { current = 1; exit }
        END {
          if (!seen || !current) {
            print "Cannot enumerate the complete Agent release range: " prev " to " cur > "/dev/stderr"
            exit 1
          }
        }')

  # Emit newest hop first to match chronological changelog order in reverse
  AGENT_VERSIONS=$(echo "$AGENT_VERSIONS" | sort -rV)
  NEWEST_AGENT_VERSION=$(echo "$AGENT_VERSIONS" | head -n 1)
  OLDEST_AGENT_VERSION=$(echo "$AGENT_VERSIONS" | tail -n 1)
  AGENT_VERSION_RANGE="v${NEWEST_AGENT_VERSION}"
  if [[ "$OLDEST_AGENT_VERSION" != "$NEWEST_AGENT_VERSION" ]]; then
    AGENT_VERSION_RANGE="v${OLDEST_AGENT_VERSION}–v${NEWEST_AGENT_VERSION}"
  fi

  # Combine every hop into a single collapsible section with a heading per version.
  # Upstream notes are kept verbatim, with headings demoted two levels so they nest
  # under the version heading.
  AGENT_CHANGELOG_SECTION="<details>
<summary><h3>Agent Changelog (${AGENT_VERSION_RANGE})</h3></summary>"
  for AGENT_VERSION in $AGENT_VERSIONS; do
    echo "--- Fetching agent release notes for v${AGENT_VERSION}"
    AGENT_RELEASE_NOTES=$(gh release view "v${AGENT_VERSION}" --repo "buildkite/agent" --json body -q .body \
      | tr -d '\r' \
      | sed -E 's/^(#+) /\1## /')
    AGENT_CHANGELOG_SECTION+="

### [v${AGENT_VERSION}](https://github.com/buildkite/agent/releases/tag/v${AGENT_VERSION})

${AGENT_RELEASE_NOTES}"
  done
  AGENT_CHANGELOG_SECTION+=$'\n\n</details>'
  CHANGELOG_BODY+=$'\n\n'"${AGENT_CHANGELOG_SECTION}"
fi

# 4. Update CHANGELOG.md, preserving the header
echo "--- Updating CHANGELOG.md"
CHANGELOG_HEADER=$(head -n 5 CHANGELOG.md)
CHANGELOG_REST=$(tail -n +6 CHANGELOG.md)

# Do not interpret backslash escapes in upstream notes (for example Windows paths).
printf '%s\n\n%s\n\n%s\n' "$CHANGELOG_HEADER" "$CHANGELOG_BODY" "$CHANGELOG_REST" >CHANGELOG.md

echo "CHANGELOG.md has been updated for ${RELEASE_VERSION}. Edit the entry, then run"
echo ".buildkite/scripts/release-notes.sh ${RELEASE_VERSION} for the GitHub release body."
