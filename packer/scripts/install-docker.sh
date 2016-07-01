#!/bin/bash

set -eu -o pipefail

DOCKER_VERSION=1.11.2
DOCKER_SHA256=8c2e0c35e3cda11706f54b2d46c2521a6e9026a7b13c7d4b8ae1f3a706fc55e1

sudo yum update -y -q
sudo yum install -y -q docker
sudo usermod -a -G docker ec2-user
sudo cp /tmp/conf/docker/docker.conf /etc/sysconfig/docker

# Overwrite the yum packaged docker with the latest
# Releases can be found at https://github.com/docker/docker/releases
# shasums can be found at $URL.sha256
echo "Downloading docker..."
curl -Lsf -o /tmp/docker.tgz https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz
echo "$DOCKER_SHA256 /tmp/docker.tgz" | sha256sum --check --strict
sudo tar -xz -C /usr/bin --strip-components 1 -f /tmp/docker.tgz

sudo service docker start || ( cat /var/log/docker && false )
sudo docker info

echo "Downloading docker-compose..."
sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/1.7.1/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose
docker-compose --version

echo "Downloading docker-gc..."
curl -Lsf https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc

echo "Downloading jq..."
sudo curl -Lsf -o /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
jq --version
