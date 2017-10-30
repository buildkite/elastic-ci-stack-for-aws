#!/bin/bash
set -eu -o pipefail

echo "Installing dependencies..."
sudo yum install -y python27-pip zip unzip git

echo "Installing bats..."
sudo yum install -y git
sudo git clone https://github.com/sstephenson/bats.git /tmp/bats
sudo /tmp/bats/install.sh /usr/local

echo "Installing bk elastic stack bin files..."
sudo chmod +x /tmp/conf/bin/bk-*
sudo mv /tmp/conf/bin/bk-* /usr/local/bin

env | grep PATH
sudo env | grep PATH
sudo -i env | grep PATH

echo "Configuring awscli to use v4 signatures..."
pip install --upgrade --user awscli
aws configure set s3.signature_version s3v4
