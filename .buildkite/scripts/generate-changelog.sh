#!/bin/bash
set -euo pipefail

if [[ -z "${1:-}" ]]; then
  echo "Usage: $0 <VERSION>"
  echo "Example: $0 v5.5.0"
  exit 1
fi

RELEASE_VERSION=$1

# 1. Get the previous release tag, excluding the current release version
PREVIOUS_TAG=$(git describe --tags --abbrev=0 --match='v*' --exclude="$RELEASE_VERSION")

# 2. Generate the changelog with ghch
echo "--- Generating changelog from ${PREVIOUS_TAG} to ${RELEASE_VERSION}"
CHANGELOG_BODY=$(ghch --format=markdown --from="$PREVIOUS_TAG" --next-version="$RELEASE_VERSION")

# 3. Check for Buildkite Agent updates
AGENT_INSTALL_SCRIPT_LINUX="packer/linux/stack/scripts/install-buildkite-agent.sh"
AGENT_INSTALL_SCRIPT_WINDOWS="packer/windows/stack/scripts/install-buildkite-agent.ps1"

extract_agent_version() {
  # Reads the pinned agent version from a given git ref's Linux install script.
  git show "$1:${AGENT_INSTALL_SCRIPT_LINUX}" 2>/dev/null | grep "AGENT_VERSION=" | cut -d'=' -f2 | tr -d '"'
}

if git diff --name-only "$PREVIOUS_TAG..HEAD" -- "$AGENT_INSTALL_SCRIPT_LINUX" "$AGENT_INSTALL_SCRIPT_WINDOWS" | grep -q "."; then
  echo "--- Buildkite Agent version has changed. Fetching agent release notes."
  PREVIOUS_AGENT_VERSION=$(extract_agent_version "$PREVIOUS_TAG")
  CURRENT_AGENT_VERSION=$(extract_agent_version HEAD)

  # The stack can jump across multiple agent releases between two stack releases
  # (e.g. v3.128.0 -> v3.129.0 -> v3.130.0). Enumerate every agent release in the
  # range (PREVIOUS_AGENT_VERSION, CURRENT_AGENT_VERSION] so no hop is skipped.
  AGENT_VERSIONS=$(gh release list --repo "buildkite/agent" --limit 200 --json tagName -q '.[].tagName' \
    | sed 's/^v//' \
    | sort -V \
    | awk -v prev="$PREVIOUS_AGENT_VERSION" -v cur="$CURRENT_AGENT_VERSION" '
        $0 == prev { seen = 1; next }
        seen { print }
        $0 == cur { exit }')

  # Fall back to just the current version if enumeration produced nothing.
  if [[ -z "$AGENT_VERSIONS" ]]; then
    AGENT_VERSIONS="$CURRENT_AGENT_VERSION"
  fi

  # Emit newest hop first to match chronological changelog order in reverse
  AGENT_CHANGELOG_SECTION=""
  for AGENT_VERSION in $(echo "$AGENT_VERSIONS" | sort -rV); do
    echo "--- Fetching agent release notes for v${AGENT_VERSION}"
    AGENT_RELEASE_NOTES=$(gh release view "v${AGENT_VERSION}" --repo "buildkite/agent" --json body -q .body)
    AGENT_CHANGELOG_SECTION+="<details>\n  <summary><h3>Agent Changelog (v${AGENT_VERSION})</h3></summary>\n\n${AGENT_RELEASE_NOTES}\n</details>\n"
  done
  CHANGELOG_BODY+="\n\n${AGENT_CHANGELOG_SECTION}"
fi

# 4. Update CHANGELOG.md, preserving the header
echo "--- Updating CHANGELOG.md"
CHANGELOG_HEADER=$(head -n 5 CHANGELOG.md)
CHANGELOG_REST=$(tail -n +6 CHANGELOG.md)

# Construct the new file content
NEW_CHANGELOG_CONTENT="${CHANGELOG_HEADER}\n\n${CHANGELOG_BODY}\n\n${CHANGELOG_REST}"

echo -e "$NEW_CHANGELOG_CONTENT" >CHANGELOG.md

echo "CHANGELOG.md has been updated for ${RELEASE_VERSION}. Please review and create a pull request."
