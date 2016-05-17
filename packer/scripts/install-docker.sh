#!/bin/bash

set -eu -o pipefail

DOCKER_VERSION=1.11.1
DOCKER_SHA256=893e3c6e89c0cd2c5f1e51ea41bc2dd97f5e791fcfa3cee28445df277836339d

sudo yum update -y -q
sudo yum install -y -q docker
sudo usermod -a -G docker ec2-user
sudo cp /tmp/conf/docker.conf /etc/sysconfig/docker

# Overwrite the yum packaged docker with the latest
# Releases can be found at https://github.com/docker/docker/releases
# shasums can be found at $URL.sha256
wget -nv https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz -O /tmp/docker.tgz
echo "$DOCKER_SHA256 /tmp/docker.tgz" | sha256sum --check --strict
sudo tar -xz -C /usr/bin --strip-components 1 -f /tmp/docker.tgz

sudo service docker start || ( cat /var/log/docker && false )
sudo docker info

# installs docker-compose
sudo curl -o /usr/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc

# install jq
sudo curl -o /usr/bin/jq -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
