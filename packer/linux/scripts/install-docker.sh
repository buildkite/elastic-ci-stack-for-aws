#!/usr/bin/env bash
set -euo pipefail

DOCKER_COMPOSE_V2_VERSION=2.18.1
DOCKER_BUILDX_VERSION="0.10.5"
MACHINE=$(uname -m)

echo Installing docker...
sudo yum install -yq docker
sudo systemctl enable --now docker

echo Add docker group
sudo usermod -a -G docker ec2-user

echo Add docker config
sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json
sudo cp /tmp/conf/docker/subuid /etc/subuid
sudo cp /tmp/conf/docker/subgid /etc/subgid
sudo chown -R ec2-user:docker /etc/docker

echo "Adding docker systemd timers..."
sudo cp /tmp/conf/docker/scripts/* /usr/local/bin
sudo cp /tmp/conf/docker/systemd/docker-* /etc/systemd/system
sudo chmod +x /usr/local/bin/docker-*
sudo systemctl daemon-reload
sudo systemctl enable docker-gc.timer docker-low-disk-gc.timer

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
