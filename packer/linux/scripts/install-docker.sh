#!/usr/bin/env bash
set -euo pipefail

DOCKER_VERSION=24.0.4
DOCKER_RELEASE=stable
DOCKER_COMPOSE_V2_VERSION=2.20.0
DOCKER_BUILDX_VERSION=0.11.2
MACHINE=$(uname -m)

echo Installing docker...
sudo dnf install -yq \
  cni-plugins \
  iptables-nft \
  xz

# Manual install ala https://docs.docker.com/engine/installation/binaries/
curl -Lsf "https://download.docker.com/linux/static/${DOCKER_RELEASE}/${MACHINE}/docker-${DOCKER_VERSION}.tgz" | \
  sudo tar -xvz -C /usr/bin --strip-components 1

echo Add docker config
sudo mkdir -p /etc/docker
sudo cp /tmp/conf/docker/daemon.json /etc/docker/daemon.json

# Add docker group
sudo groupadd -r docker
sudo usermod -aG docker ec2-user

CONTAINERD_VERSION=$(containerd --version | awk '{print $3}')

echo Installing systemd services...
sudo curl -Lfs \
  -o /etc/systemd/system/docker.service \
  "https://raw.githubusercontent.com/moby/moby/v${DOCKER_VERSION}/contrib/init/systemd/docker.service"
sudo curl -Lfs \
  -o /etc/systemd/system/docker.socket \
  "https://raw.githubusercontent.com/moby/moby/v${DOCKER_VERSION}/contrib/init/systemd/docker.socket"
sudo curl -Lfs \
  -o /etc/systemd/system/containerd.service \
  "https://raw.githubusercontent.com/containerd/containerd/${CONTAINERD_VERSION}/containerd.service"
sudo sed -i 's,/sbin,/usr/bin,;s,/usr/local,/usr,' /etc/systemd/system/containerd.service

sudo systemctl daemon-reload
sudo systemctl enable --now containerd docker

echo Adding docker systemd timers...
sudo cp /tmp/conf/docker/scripts/* /usr/local/bin
sudo cp /tmp/conf/docker/systemd/docker-* /etc/systemd/system
sudo chmod +x /usr/local/bin/docker-*
sudo systemctl daemon-reload
sudo systemctl enable docker-gc.timer docker-low-disk-gc.timer

DOCKER_CLI_DIR=/usr/libexec/docker/cli-plugins

echo Installing docker buildx...
case "${MACHINE}" in
  x86_64) BUILDX_ARCH="amd64";;
  aarch64) BUILDX_ARCH="arm64";;
esac
sudo mkdir -p "${DOCKER_CLI_DIR}"
sudo curl --location --fail --silent \
  --output "${DOCKER_CLI_DIR}/docker-buildx" \
  "https://github.com/docker/buildx/releases/download/v${DOCKER_BUILDX_VERSION}/buildx-v${DOCKER_BUILDX_VERSION}.linux-${BUILDX_ARCH}"
sudo chmod +x "${DOCKER_CLI_DIR}/docker-buildx"
docker buildx version

echo Installing docker compose...
DOCKER_COMPOSE_V2_ARCH="${MACHINE}"
sudo curl --location --fail --silent \
  --output "${DOCKER_CLI_DIR}/docker-compose" \
  "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_V2_VERSION}/docker-compose-linux-${DOCKER_COMPOSE_V2_ARCH}"
sudo chmod +x "${DOCKER_CLI_DIR}/docker-compose"
docker compose version

echo Making docker compose v2 compatible w/ docker-compose v1...
sudo ln -s "${DOCKER_CLI_DIR}/docker-compose" /usr/bin/docker-compose
sudo cp /tmp/conf/bin/docker-compose /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose version

# See https://docs.docker.com/build/building/multi-platform/
echo Pull image for multiarch...
QEMU_BINFMT_VERSION=7.0.0-28
QEMU_BINFMT_DIGEST=sha256:66e11bea77a5ea9d6f0fe79b57cd2b189b5d15b93a2bdb925be22949232e4e55
QEMU_BINFMT_TAG="qemu-v${QEMU_BINFMT_VERSION}@${QEMU_BINFMT_DIGEST}"
sudo mkdir -p /usr/local/lib
echo "QEMU_BINFMT_TAG=\"$QEMU_BINFMT_TAG\"" | sudo tee -a /usr/local/lib/bk-configure-docker.sh
sudo docker pull "tonistiigi/binfmt:${QEMU_BINFMT_TAG}"
