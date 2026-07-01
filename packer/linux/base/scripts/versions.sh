#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.35.13"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.835.0"

# Development Tools
export GIT_LFS_VERSION="3.7.1"

# goss is built from source (build/goss-* in the Makefile), pinned to a commit
# because the dependency-bump fix (https://github.com/goss-org/goss/pull/1064)
# for the Go CVEs is not in any release yet (latest is v0.4.9). Revert to a
# release download once a version above v0.4.9 ships with the fix.
# GOSS_VERSION derives its short hash from GOSS_COMMIT, so a Renovate digest
# bump updates both. Bump the base version (v0.4.9) when goss next tags a release.
export GOSS_COMMIT="c4634acb0ff00fff08438b2396deb72e6b2b9d83"
GOSS_VERSION="v0.4.9-dev-$(printf '%.7s' "$GOSS_COMMIT")"
export GOSS_VERSION

# Container Tools
export DOCKER_COMPOSE_V2_VERSION="5.1.4"
export DOCKER_BUILDX_VERSION="0.34.1"

# Buildkite Tools
export S3_SECRETS_HELPER_VERSION="2.8.0"
export LIFECYCLED_VERSION="v3.6.0"
