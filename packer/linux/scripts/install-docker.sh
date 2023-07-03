#!/usr/bin/env bash
set -euo pipefail

DOCKER_COMPOSE_V2_VERSION=2.19.1
DOCKER_BUILDX_VERSION="0.11.0"
MACHINE=$(uname -m)

echo Installing docker...
sudo dnf install -yq docker
sudo systemctl enable --now docker

echo Add ec2-user to docker group.
sudo usermod -a -G docker ec2-user

echo Add docker config
sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json

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

echo "Making docker compose v2 compatible w/ docker-compose v1..."
sudo ln -s "${DOCKER_CLI_DIR}/docker-compose" /usr/bin/docker-compose
sudo cp /tmp/conf/bin/docker-compose /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version

# See https://docs.docker.com/build/building/multi-platform/
QEMU_BINFMT_VERSION=7.0.0-28
QEMU_BINFMT_DIGEST=sha256:66e11bea77a5ea9d6f0fe79b57cd2b189b5d15b93a2bdb925be22949232e4e55
QEMU_BINFMT_TAG="qemu-v${QEMU_BINFMT_VERSION}@${QEMU_BINFMT_DIGEST}"
sudo mkdir -p /usr/local/lib
echo "QEMU_BINFMT_TAG=\"$QEMU_BINFMT_TAG\"" | sudo tee -a /usr/local/lib/bk-install-elastic-stack.sh
echo Pulling qemu binfmt for multiarch...
sudo docker pull "tonistiigi/binfmt:${QEMU_BINFMT_TAG}"
