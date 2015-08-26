#!/bin/bash -eux

# install Docker engine
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo 'deb https://apt.dockerproject.org/repo ubuntu-vivid main' | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -q
sudo apt-get install -q -y docker-engine
sudo usermod -aG docker ubuntu
sudo mv /tmp/conf/docker.defaults /etc/default/docker
sudo chown root: /etc/default/docker
sudo mv /tmp/conf/docker.service /lib/systemd/system/docker.service
sudo chown root: /lib/systemd/system/docker.service
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl is-active docker
sudo docker info

# installs systemd-docker
sudo curl -o /usr/local/bin/systemd-docker -L https://github.com/ibuildthecloud/systemd-docker/releases/download/v0.2.0/systemd-docker
sudo chmod +x /usr/local/bin/systemd-docker

# installs docker-compose
sudo curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.4.0rc3/docker-compose-Linux-x86_64
sudo chmod +x /usr/local/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc