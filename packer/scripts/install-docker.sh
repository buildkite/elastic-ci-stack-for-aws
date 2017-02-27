#!/bin/bash
set -eu -o pipefail

DOCKER_COMPOSE_VERSION=1.11.0

echo "Configuring docker..."
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Adding docker-gc cron task..."
sudo cp /tmp/conf/docker/cron.daily/docker-gc /etc/cron.daily/docker-gc
sudo chmod +x /etc/cron.daily/docker-gc