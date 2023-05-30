#!/bin/bash
set -eu -o pipefail

DOCKER_VERSION=20.10.23
DOCKER_RELEASE="stable"
DOCKER_COMPOSE_V2_VERSION=2.16.0
DOCKER_BUILDX_VERSION="0.10.5"
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

echo "Adding docker systemd timers..."
sudo cp /tmp/conf/docker/scripts/* /usr/local/bin
sudo cp /tmp/conf/docker/systemd/docker-* /etc/systemd/system
sudo chmod +x /usr/local/bin/docker-*
sudo systemctl daemon-reload
sudo systemctl enable docker-gc.timer docker-low-disk-gc.timer

echo "Installing jq..."
sudo yum install -y -q jq
jq --version

echo "Installing docker buildx..."
DOCKER_CLI_DIR=/usr/libexec/docker/cli-plugins
sudo mkdir -p "${DOCKER_CLI_DIR}"

DOCKER_COMPOSE_V2_ARCH="${MACHINE}"
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

sudo curl --location --fail --silent --output "${DOCKER_CLI_DIR}/docker-compose" "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_V2_VERSION}/docker-compose-linux-${DOCKER_COMPOSE_V2_ARCH}"
sudo chmod +x "${DOCKER_CLI_DIR}/docker-compose"
docker compose version

sudo ln -s "${DOCKER_CLI_DIR}/docker-compose" /usr/bin/docker-compose
docker-compose version
