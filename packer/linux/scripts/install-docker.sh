#!/bin/bash
set -eu -o pipefail

DOCKER_VERSION=20.10.6
DOCKER_RELEASE="stable"
DOCKER_COMPOSE_VERSION=1.28.6
DOCKER_BUILDX_VERSION="0.5.1"
MACHINE=$(uname -m)

# This performs a manual install of Docker.

# Add docker group
sudo groupadd docker
sudo usermod -a -G docker ec2-user

# Manual install ala https://docs.docker.com/engine/installation/binaries/
curl -Lsf -o docker.tgz "https://download.docker.com/linux/static/${DOCKER_RELEASE}/${MACHINE}/docker-${DOCKER_VERSION}.tgz"
tar -xvzf docker.tgz
sudo mv docker/* /usr/bin
rm docker.tgz

sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json
sudo cp /tmp/conf/docker/subuid /etc/subuid
sudo cp /tmp/conf/docker/subgid /etc/subgid
sudo chown -R ec2-user:docker /etc/docker

# Install systemd services
echo "Installing systemd services"
sudo curl -Lfs -o /etc/systemd/system/docker.service "https://raw.githubusercontent.com/moby/moby/v${DOCKER_VERSION}/contrib/init/systemd/docker.service"
sudo curl -Lfs -o /etc/systemd/system/docker.socket "https://raw.githubusercontent.com/moby/moby/v${DOCKER_VERSION}/contrib/init/systemd/docker.socket"
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

echo "Installing docker buildx..."

DOCKER_CLI_DIR=/usr/libexec/docker/cli-plugins
sudo mkdir -p "${DOCKER_CLI_DIR}"

case "${MACHINE}" in
  x86_64)
    BUILDX_ARCH="amd64";
    ;;
  aarch64)
    BUILDX_ARCH="arm64";
    ;;
esac

sudo curl --location --fail --silent --output "${DOCKER_CLI_DIR}/docker-buildx" "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${BUILDX_ARCH}"
sudo chmod +x "${DOCKER_CLI_DIR}/docker-buildx"
docker buildx version
