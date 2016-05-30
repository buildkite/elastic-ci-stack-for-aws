#!/bin/bash

set -eu -o pipefail

PACKER_VERSION=0.10.1
PACKER_SHA256=7d51fc5db19d02bbf32278a8116830fae33a3f9bd4440a58d23ad7c863e92e28

wget -q https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip -O /tmp/packer.zip
echo "$PACKER_SHA256 /tmp/packer.zip" | sha256sum --check --strict
sudo unzip /tmp/packer.zip -d /usr/bin

