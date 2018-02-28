#!/bin/bash

set -eu -o pipefail

echo "Installing awslogs..."
sudo yum update -y -q
sudo yum install -y awslogs

echo "Adding awslogs config..."
sudo mkdir -p /var/awslogs/state
sudo cp /tmp/conf/awslogs/awslogs.conf /etc/awslogs/awslogs.conf

echo "Configure awslogsd to run on startup..."
sudo systemctl enable awslogsd.service
