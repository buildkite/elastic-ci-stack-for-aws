#!/bin/bash
set -eu -o pipefail

echo "Installing zip utils..."
sudo yum update -y -q
sudo yum install -y zip unzip

echo "Installing bats..."
sudo yum install -y git
sudo git clone https://github.com/sstephenson/bats.git /tmp/bats
sudo /tmp/bats/install.sh /usr/local

echo "Installing bk elastic stack bin files..."
sudo chmod +x /tmp/conf/bin/bk-*
sudo mv /tmp/conf/bin/bk-* /usr/local/bin

echo "Installing aws-cli tools..."
sudo yum install -y aws-cli aws-cfn-bootstrap
sudo aws configure set s3.signature_version s3v4

echo "Installing ec2-metadata script"
sudo curl -Lsf -o /opt/aws/bin/ec2-metadata http://s3.amazonaws.com/ec2metadata/ec2-metadata
sudo chmod +x /opt/aws/bin/ec2-metadata

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version