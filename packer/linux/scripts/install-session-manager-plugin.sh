#!/bin/bash
set -eu -o pipefail

SESSION_MANAGER_PLUGIN_VERSION=1.2.30.0

MACHINE="$(uname -m)"

case "${MACHINE}" in
	x86_64)    ARCH=64bit;;
	aarch64)   ARCH=arm64;;
	*)         ARCH=unknown;;
esac

echo "Installing session-manager-plugin $SESSION_MANAGER_PLUGIN_VERSION..."

curl \
  "https://s3.amazonaws.com/session-manager-downloads/plugin/$SESSION_MANAGER_PLUGIN_VERSION/linux_$ARCH/session-manager-plugin.rpm" \
  -o /tmp/session-manager-plugin.rpm
sudo yum install -y /tmp/session-manager-plugin.rpm
rm /tmp/session-manager-plugin.rpm
