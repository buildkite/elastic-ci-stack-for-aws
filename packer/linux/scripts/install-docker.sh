#!/bin/bash
set -eu -o pipefail

DOCKER_VERSION=20.10.6
DOCKER_RELEASE="stable"
DOCKER_COMPOSE_VERSION=1.28.6
MACHINE=$(uname -m)

# Add docker group
sudo groupadd docker
sudo usermod -a -G docker ec2-user

# Add the Docker yum repository, but override the url to get CentOS 7 not
# CentOS 2 (the default with Amazon Linux 2 applied to the interpolation)
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum-config-manager --setopt="docker-ce-stable.baseurl=https://download.docker.com/linux/centos/7/$MACHINE/stable" --save

# Add CentOS 7 Base and Extras to the yum repos list, needed for deps for
# packages from the Docker yum repo
cat << 'EOF' | sudo tee /etc/yum.repos.d/centos.repo
[base]
name=CentOS-7 - Base
mirrorlist=http://mirrorlist.centos.org/?release=7&arch=$basearch&repo=os
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
priority=1

[extras]
name=CentOS-7 - Extras
mirrorlist=http://mirrorlist.centos.org/?release=7&arch=$basearch&repo=extras
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
priority=1
EOF

# Download the signing key for the repository
sudo curl --fail --location --output /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7 https://centos.org/keys/RPM-GPG-KEY-CentOS-7
sudo rpm -import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7

# Do the install
sudo yum install -y -q "docker-ce-${DOCKER_VERSION}" "docker-ce-cli-${DOCKER_VERSION}" containerd.io

sudo systemctl daemon-reload
sudo systemctl enable docker.service

if [ "${MACHINE}" == "x86_64" ]; then
	echo "Downloading docker-compose..."
	sudo curl -Lsf -o /usr/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-Linux-x86_64
	sudo chmod +x /usr/bin/docker-compose
	docker-compose --version
elif [[ "${MACHINE}" == "aarch64" ]]; then
  sudo yum install -y gcc-c++ libffi-devel openssl11 openssl11-devel python3-devel

  # docker-compose depends on the cryptography package, v3.4 of which
  # introduces a build dependency on rust; let's avoid that for now.
  # https://github.com/pyca/cryptography/blob/master/CHANGELOG.rst#34---2021-02-07
  # This should be unpinned ASAP; hopefully docker-compose will offer binary
  # download for arm64 at some point:
  # https://github.com/docker/compose/issues/7472
  CONSTRAINT_FILE="/tmp/docker-compose-pip-constraint"
  echo 'cryptography<3.4' >"$CONSTRAINT_FILE"
  sudo pip3 install --constraint "$CONSTRAINT_FILE" "docker-compose==${DOCKER_COMPOSE_VERSION}"

	docker-compose version
else
  echo "No docker compose option configured for arch ${MACHINE}"
  exit 1
fi

echo "Adding docker cron tasks..."
sudo cp /tmp/conf/docker/cron.hourly/docker-gc /etc/cron.hourly/docker-gc
sudo cp /tmp/conf/docker/cron.hourly/docker-low-disk-gc /etc/cron.hourly/docker-low-disk-gc
sudo chmod +x /etc/cron.hourly/docker-*

echo "Installing jq..."
sudo yum install -y -q jq
jq --version
