#!/bin/bash

set -eu -o pipefail

echo "Installing zip utils..."
sudo yum update -y -q
sudo yum install -y zip unzip

echo "Installing bk elastic stack bin files"
chod +x /tmp/bin/bk-*
mv /tmp/bin/bk-* /usr/local/bin
