#!/bin/bash
set -eu -o pipefail

LIFECYCLED_VERSION=v3.2.0

MACHINE=$(uname -m)

case "${MACHINE}" in
	x86_64)    ARCH=amd64;;
	aarch64)   ARCH=arm64;;
	*)         ARCH=unknown;;
esac

echo "Installing lifecycled ${LIFECYCLED_VERSION}..."

sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-${ARCH}
sudo chmod +x /usr/bin/lifecycled
sudo curl -Lf -o /etc/systemd/system/lifecycled.service \
	https://raw.githubusercontent.com/lox/lifecycled/${LIFECYCLED_VERSION}/init/systemd/lifecycled.unit

