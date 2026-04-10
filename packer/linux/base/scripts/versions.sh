#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.34.21"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.792.0"

# Development Tools
export GIT_LFS_VERSION="3.4.0"
export GOSS_VERSION="v0.4.9"

# Container Tools (buildx and compose are installed as Docker repo dependencies)
export DOCKER_VERSION="29.4.0"

# Buildkite Tools
export S3_SECRETS_HELPER_VERSION="2.8.0"
export LIFECYCLED_VERSION="v3.5.0"
