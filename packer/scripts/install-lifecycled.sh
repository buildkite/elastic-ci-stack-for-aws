#!/bin/bash
set -eu -o pipefail

LIFECYCLED_VERSION=v2.0.1

echo "Installing lifecycled ${LIFECYCLED_VERSION}..."

sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-amd64
sudo chmod +x /usr/bin/lifecycled
sudo curl -Lf -o /etc/init/lifecycled.conf \
	https://raw.githubusercontent.com/lox/lifecycled/${LIFECYCLED_VERSION}/init/upstart/lifecycled.conf
