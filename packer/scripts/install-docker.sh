#!/bin/bash

# setup btrfs on /dev/xvdf
sudo apt-get install -y btrfs-tools
printf 'LABEL=docker %s\t%s\tauto\tdefaults,noatime\t0 0\n' /dev/xvdf /var/lib/docker >> /etc/fstab
mkfs.btrfs /dev/xvdf
mkdir -p /var/lib/docker
mount /dev/xvdf /var/lib/docker

# installs docker
curl -sSL https://get.docker.com/ | sudo sh
sudo usermod -aG docker ubuntu
sudo mv /tmp/conf/docker.defaults /etc/default/docker
sudo chown root: /etc/default/docker
sudo mv /tmp/conf/docker.service /lib/systemd/system/docker.service
sudo chown root: /lib/systemd/system/docker.service
sudo systemctl daemon-reload
sudo systemctl enable docker

# installs docker-compose
sudo curl -o /usr/local/bin/docker-compose -L https://github.com/docker/compose/releases/download/1.3.0rc2/docker-compose-Linux-x86_64
sudo chmod +x /usr/local/bin/docker-compose

# install docker-gc
curl -L https://raw.githubusercontent.com/spotify/docker-gc/master/docker-gc > docker-gc
sudo mv docker-gc /etc/cron.hourly/docker-gc
sudo chmod +x /etc/cron.hourly/docker-gc