#!/bin/bash -eu

sudo yum update -yq
sudo yum install -yq docker
sudo usermod -a -G docker ec2-user

sudo service docker start
sudo docker info

# installs docker-compose
sudo curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.5.0/docker-compose-Linux-x86_64
sudo chmod +x /usr/local/bin/docker-compose

# # install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc