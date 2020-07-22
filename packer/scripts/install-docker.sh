#!/bin/bash
set -eu -o pipefail

DOCKER_VERSION=19.03.12
DOCKER_RELEASE="stable"
DOCKER_COMPOSE_VERSION=1.26.2

# This performs a manual install of Docker.

# Add docker group
sudo groupadd docker
sudo usermod -a -G docker ec2-user

# Manual install ala https://docs.docker.com/engine/installation/binaries/
curl -Lsf -o docker.tgz https://download.docker.com/linux/static/${DOCKER_RELEASE}/x86_64/docker-${DOCKER_VERSION}.tgz
tar -xvzf docker.tgz
sudo mv docker/* /usr/bin
rm docker.tgz

sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json
sudo cp /tmp/conf/docker/subuid /etc/subuid
sudo cp /tmp/conf/docker/subgid /etc/subgid
sudo chown -R ec2-user:docker /etc/docker

# Install systemd services
echo "Installing systemd services"
sudo curl -Lfs -o /etc/systemd/system/docker.service https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.service
sudo curl -Lfs -o /etc/systemd/system/docker.socket https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.socket
sudo systemctl daemon-reload
sudo systemctl enable docker.service

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Adding docker cron tasks..."
sudo cp /tmp/conf/docker/cron.hourly/docker-gc /etc/cron.hourly/docker-gc
sudo cp /tmp/conf/docker/cron.hourly/docker-low-disk-gc /etc/cron.hourly/docker-low-disk-gc
sudo chmod +x /etc/cron.hourly/docker-*

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version

