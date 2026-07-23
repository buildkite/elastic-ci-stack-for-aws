#!/usr/bin/env bash
set -euo pipefail

# Source centralized version definitions
# shellcheck disable=SC1091
source "/tmp/versions.sh"
# shellcheck disable=SC1091
source "/tmp/distro.sh"
MACHINE=$(uname -m)

echo Installing docker...
case "${OS_DISTRO}" in
amazonlinux2023)
  pkg_install docker
  ;;
ubuntu2404)
  # docker.io is Ubuntu's packaged engine; buildx/compose plugins are added below.
  pkg_install docker.io
  ;;
esac
sudo systemctl enable --now docker

echo "Add ${LOGIN_USER} to docker group."
sudo usermod -a -G docker "${LOGIN_USER}"

echo Add docker config
sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json

echo "Adding docker systemd timers..."
sudo cp /tmp/conf/docker/scripts/* /usr/local/bin
sudo cp /tmp/conf/docker/systemd/docker-* /etc/systemd/system
sudo chmod 755 /usr/local/bin/docker-*

echo "Installing docker buildx..."
DOCKER_CLI_DIR=/usr/libexec/docker/cli-plugins
sudo mkdir -p "${DOCKER_CLI_DIR}"

DOCKER_COMPOSE_V2_ARCH="${MACHINE}"
case "${MACHINE}" in
x86_64) BUILDX_ARCH="amd64" ;;
aarch64) BUILDX_ARCH="arm64" ;;
esac

sudo curl --location --fail --silent --output "${DOCKER_CLI_DIR}/docker-buildx" "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${BUILDX_ARCH}"
sudo chmod 755 "${DOCKER_CLI_DIR}/docker-buildx"

sudo curl --location --fail --silent --output "${DOCKER_CLI_DIR}/docker-compose" "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_V2_VERSION}/docker-compose-linux-${DOCKER_COMPOSE_V2_ARCH}"
sudo chmod 755 "${DOCKER_CLI_DIR}/docker-compose"

docker buildx version
docker compose version

echo "Making docker compose v2 compatible w/ docker-compose v1..."
sudo ln -s "${DOCKER_CLI_DIR}/docker-compose" /usr/bin/docker-compose
sudo cp /tmp/conf/bin/docker-compose /usr/local/bin/docker-compose
sudo chmod 755 /usr/local/bin/docker-compose
docker-compose version

sudo mkdir -p /usr/local/lib

echo "enable binfmt_misc..."
sudo systemctl enable proc-sys-fs-binfmt_misc.mount

echo Enabling docker-binfmt...
sudo systemctl enable docker-binfmt.service

echo Start docker-binfmt...
sudo systemctl start docker-binfmt.service

echo "show docker-binfmt status..."
systemctl status docker-binfmt.service

echo "Installing Amazon ECR credential helper..."
pkg_install amazon-ecr-credential-helper
