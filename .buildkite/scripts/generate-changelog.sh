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
AGENT_INSTALL_SCRIPT_LINUX="packer/linux/scripts/install-buildkite-agent.sh"
AGENT_INSTALL_SCRIPT_WINDOWS="packer/windows/scripts/install-buildkite-agent.ps1"

if git diff --name-only "$PREVIOUS_TAG..HEAD" -- "$AGENT_INSTALL_SCRIPT_LINUX" "$AGENT_INSTALL_SCRIPT_WINDOWS" | grep -q "."; then
  echo "--- Buildkite Agent version has changed. Fetching agent release notes."
  AGENT_VERSION=$(grep "AGENT_VERSION=" "$AGENT_INSTALL_SCRIPT_LINUX" | cut -d'=' -f2)
  AGENT_RELEASE_NOTES=$(gh release view "v${AGENT_VERSION}" --repo "buildkite/agent" --json body -q .body)
  AGENT_CHANGELOG_DETAILS="<details>\n  <summary><h3>Agent Changelog</h3></summary>\n\n${AGENT_RELEASE_NOTES}\n</details>"
  CHANGELOG_BODY+="\n\n${AGENT_CHANGELOG_DETAILS}"
fi

# 4. Update CHANGELOG.md, preserving the header
echo "--- Updating CHANGELOG.md"
CHANGELOG_HEADER=$(head -n 5 CHANGELOG.md)
CHANGELOG_REST=$(tail -n +6 CHANGELOG.md)

# Construct the new file content
NEW_CHANGELOG_CONTENT="${CHANGELOG_HEADER}\n\n${CHANGELOG_BODY}\n\n${CHANGELOG_REST}"

echo -e "$NEW_CHANGELOG_CONTENT" >CHANGELOG.md

echo "CHANGELOG.md has been updated for ${RELEASE_VERSION}. Please review and create a pull request."
