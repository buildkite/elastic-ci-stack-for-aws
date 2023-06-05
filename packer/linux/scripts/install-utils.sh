#!/bin/bash
set -eu -o pipefail

echo "Updating core packages"
sudo yum update -y

echo "Installing python..."
sudo yum install -y python3-pip python3 python3-setuptools

echo "Installing zip utils..."
sudo yum install -y zip unzip git pigz

echo "Installing aws utils..."
sudo yum install -y awscli-2 aws-cfn-bootstrap

echo "Installing bk elastic stack bin files..."
sudo chmod +x /tmp/conf/bin/bk-*
sudo mv /tmp/conf/bin/bk-* /usr/local/bin

echo "Installing goss for system validation..."
curl -fsSL https://goss.rocks/install | GOSS_VER=v0.3.20 sudo sh
