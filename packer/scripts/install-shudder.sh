#!/bin/bash
set -eu -o pipefail

echo "Installing shudder..."
sudo pip install shudder==0.1.0
sudo mkdir /etc/shudder
sudo cp /tmp/conf/shudder/upstart/* /etc/init
