#!/bin/bash -eu

sudo apt-get install -yy linux-image-extra-$(uname -r) linux-image-extra-virtual aufs-tools

# install Docker engine
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-vivid main' | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -qq
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo mv /tmp/conf/docker.override.conf /etc/systemd/system/docker.service.d/override.conf
sudo chown -R root: /etc/systemd/system/docker.service.d
sudo apt-get install -y docker-engine=1.9*
sudo usermod -aG docker ubuntu
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl is-active docker
sudo systemctl status docker

# installs docker-compose
sudo curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.5.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/local/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc