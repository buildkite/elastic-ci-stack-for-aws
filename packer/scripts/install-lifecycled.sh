#!/bin/bash

set -eu -o pipefail

LIFECYCLED_VERSION=v1.1.3

echo "Downloading lifecycled..."

sudo touch /etc/lifecycled
sudo curl -Lsf -o /usr/bin/lifecycled \
	https://github.com/lox/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-x86_64
sudo chmod +x /usr/bin/lifecycled

echo "Downloading lifecycled.conf..."

sudo curl -Lsf -o /etc/init/lifecycled.conf \
	https://raw.githubusercontent.com/lox/lifecycled/${LIFECYCLED_VERSION}/init/upstart/lifecycled.conf
