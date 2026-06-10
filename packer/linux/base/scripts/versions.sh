#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.34.58"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.814.0"

# Development Tools
export GIT_LFS_VERSION="3.7.1"
export GOSS_VERSION="v0.4.9"

# Container Tools
export DOCKER_COMPOSE_V2_VERSION="5.1.4"
export DOCKER_BUILDX_VERSION="0.34.1"

# Buildkite Tools
export S3_SECRETS_HELPER_VERSION="2.8.0"
export LIFECYCLED_VERSION="v3.5.0"
