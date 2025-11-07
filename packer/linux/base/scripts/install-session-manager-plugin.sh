#!/bin/bash
set -eu -o pipefail

# Source centralized version definitions
# shellcheck disable=SC1091
source "/tmp/versions.sh"

MACHINE="$(uname -m)"

case "${MACHINE}" in
x86_64) ARCH=64bit ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo "Installing session-manager-plugin ${SESSION_MANAGER_PLUGIN_VERSION}..."

sudo dnf install -y "https://s3.amazonaws.com/session-manager-downloads/plugin/${SESSION_MANAGER_PLUGIN_VERSION}/linux_${ARCH}/session-manager-plugin.rpm"
