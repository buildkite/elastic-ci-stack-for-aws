#!/bin/bash

set -eu -o pipefail

sudo yum update -y -q
sudo yum install -y -q docker-1.11.2
sudo usermod -a -G docker ec2-user

# Change storage driver from devicemapper to overlay
sudo rm -rf /var/lib/docker/
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/1.7.1/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Downloading docker-gc..."
curl -Lsf https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /usr/bin/docker-gc

echo "Adding docker-gc cron task..."
sudo cp /tmp/conf/docker/cron.daily/docker-gc /etc/cron.daily/docker-gc
sudo chmod +x /etc/cron.daily/docker-gc

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version
