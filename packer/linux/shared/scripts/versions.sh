#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.31.32"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.677.0"

# Development Tools
export GIT_LFS_VERSION="3.4.0"
export GOSS_VERSION="v0.3.23"

# Container Tools
export DOCKER_COMPOSE_V2_VERSION="2.38.2"
export DOCKER_BUILDX_VERSION="0.26.1"

# Buildkite Tools
export AGENT_VERSION="3.111.0"
export S3_SECRETS_HELPER_VERSION="2.7.0"
export LIFECYCLED_VERSION="v3.4.0"
