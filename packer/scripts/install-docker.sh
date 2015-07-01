#!/bin/bash -eu

# Install Docker daemon.
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
echo 'deb https://get.docker.com/ubuntu docker main' | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update -q
sudo apt-get install -q -y linux-image-extra-`uname -r`
sudo apt-get install -q -y lxc-docker-1.6.2
sudo usermod -aG docker ubuntu
sudo mv /tmp/conf/docker.defaults /etc/default/docker
sudo chown root: /etc/default/docker
sudo mv /tmp/conf/docker.service /lib/systemd/system/docker.service
sudo chown root: /lib/systemd/system/docker.service
sudo systemctl daemon-reload
sudo systemctl enable docker

# Install ssh-agent service
sudo mv /tmp/conf/ssh-agent.service /lib/systemd/system/ssh-agent.service
sudo chown root: /lib/systemd/system/ssh-agent.service

# installs docker-compose
sudo curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.3.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/local/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc