#!/bin/bash
set -eu -o pipefail

# Source centralized version definitions
# shellcheck disable=SC1091
source "/tmp/versions.sh"
# shellcheck disable=SC1091
source "/tmp/distro.sh"

MACHINE="$(uname -m)"

case "${MACHINE}" in
x86_64) ARCH=64bit ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo "Installing session-manager-plugin ${SESSION_MANAGER_PLUGIN_VERSION}..."

BASE_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/${SESSION_MANAGER_PLUGIN_VERSION}"
case "${OS_DISTRO}" in
amazonlinux2023)
  pkg_install_local "${BASE_URL}/linux_${ARCH}/session-manager-plugin.rpm"
  ;;
ubuntu2404)
  pushd "$(mktemp -d)"
  curl -sSL "${BASE_URL}/ubuntu_${ARCH}/session-manager-plugin.deb" -o session-manager-plugin.deb
  pkg_install_local ./session-manager-plugin.deb
  popd
  ;;
esac
