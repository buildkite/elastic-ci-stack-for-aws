#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.38.4"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.896.0"

# Development Tools
export GIT_LFS_VERSION="3.8.0"
export GOSS_VERSION="v0.4.10"

# Container Tools
export DOCKER_COMPOSE_V2_VERSION="5.6.1"
export DOCKER_BUILDX_VERSION="0.38.1"
export DOCKER_BINFMT_IMAGE="tonistiigi/binfmt:qemu-v10.2.3-68@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0"

# Buildkite Tools
export S3_SECRETS_HELPER_VERSION="2.9.0"
export LIFECYCLED_VERSION="v3.7.0"
