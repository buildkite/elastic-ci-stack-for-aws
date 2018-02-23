#!/bin/bash
set -eu -o pipefail

DOCKER_VERSION=17.12.1-ce-rc2
DOCKER_RELEASE="test"
DOCKER_COMPOSE_VERSION=1.18.0

# This performs a manual install of Docker. The init.d script is from the
# 1.11 yum package

echo "Installing docker..."

# Only dep to install (found by doing a yum install of 1.11)
sudo yum install -y xfsprogs

# Add docker group
sudo groupadd docker
sudo usermod -a -G docker ec2-user

# Manual install ala https://docs.docker.com/engine/installation/binaries/
curl -Lsf https://download.docker.com/linux/static/${DOCKER_RELEASE}/x86_64/docker-${DOCKER_VERSION}.tgz > docker.tgz
tar -xvzf docker.tgz
sudo mv docker/* /usr/bin
rm docker.tgz

sudo cp /tmp/conf/docker/init.d/docker /etc/init.d/docker
sudo cp /tmp/conf/docker/docker.userns-remap.conf /etc/sysconfig/docker.userns-remap
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker.root
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker
sudo cp /tmp/conf/docker/subuid /etc/subuid
sudo cp /tmp/conf/docker/subgid /etc/subgid
sudo chkconfig docker on

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Adding docker cron tasks..."
sudo cp /tmp/conf/docker/cron.hourly/docker-gc /etc/cron.daily/docker-gc
sudo cp /tmp/conf/docker/cron.hourly/docker-low-disk-gc /etc/cron.daily/docker-low-disk-gc
sudo chmod +x /etc/cron.daily/docker-*

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version

