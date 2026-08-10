#!/bin/bash
# Centralized version definitions for Linux packer builds
# This file is sourced by installation scripts

# Core Tools
export AWS_CLI_LINUX_VERSION="2.35.13"
export SESSION_MANAGER_PLUGIN_VERSION="1.2.835.0"

# Development Tools
export GIT_LFS_VERSION="3.7.1"
export GOSS_VERSION="v0.4.10"

# Container Tools
export DOCKER_COMPOSE_V2_VERSION="5.1.4"
export DOCKER_BUILDX_VERSION="0.34.1"
export DOCKER_BINFMT_IMAGE="tonistiigi/binfmt:qemu-v7.0.0-28@sha256:66e11bea77a5ea9d6f0fe79b57cd2b189b5d15b93a2bdb925be22949232e4e55"

# Buildkite Tools
export S3_SECRETS_HELPER_VERSION="2.8.0"
export LIFECYCLED_VERSION="v3.6.0"
