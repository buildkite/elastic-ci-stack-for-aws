#!/bin/bash -eu

DOCKER_VERSION=1.10.3
DOCKER_SHA256=a8315f0ff661e6a24a8b83743b6a4be87765bd000fab628de1a8c398b84966cc

sudo yum update -yq
sudo yum install -yq docker
sudo usermod -a -G docker ec2-user
sudo cp /tmp/conf/docker.conf /etc/sysconfig/docker

# Overwrite the yum packaged docker with the latest
# Releases can be found at https://github.com/docker/docker/releases
# shasums can be found at $URL.sha256
wget https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION -o /tmp/docker
echo "$DOCKER_SHA256 /tmp/docker" | sha256sum --check --strict
sudo cp /tmp/docker /usr/bin/docker
sudo chmod +x /usr/bin/docker

sudo service docker start || ( cat /var/log/docker && false )
sudo docker info

# installs docker-compose
sudo curl -o /usr/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.5.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc

# install jq
sudo curl -o /usr/bin/jq -L https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
sudo chmod +x /usr/bin/jq
