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
# See https://github.com/goss-org/goss/releases for release versions
GOSS_VERSION=v0.3.23
case $(uname -m) in
  amd64|x86_64) GOSS_ARCH=amd64 ;;
  armv8?|arm64|aarch64) GOSS_ARCH=arm64 ;;
  armv7?|arm) GOSS_ARCH=arm ;;
esac
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${GOSS_ARCH}" -o /usr/local/bin/goss
sudo chmod +rx /usr/local/bin/goss
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/dgoss" -o /usr/local/bin/dgoss
sudo chmod +rx /usr/local/bin/dgoss
