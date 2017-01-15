#!/bin/bash

set -eu -o pipefail

echo "Installing docker..."
sudo yum install -y docker
sudo usermod -a -G docker ec2-user

# Use the overlay2 driver
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker

# Start docker on system start
sudo chkconfig docker on

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/1.9.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Downloading docker-gc..."
curl -Lsf https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /usr/bin/docker-gc
sudo chmod +x /usr/bin/docker-gc

echo "Adding docker-gc cron task..."
sudo cp /tmp/conf/docker/cron.daily/docker-gc /etc/cron.daily/docker-gc
sudo chmod +x /etc/cron.daily/docker-gc

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version
