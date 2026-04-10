#!/usr/bin/env bash
set -euo pipefail

# Source centralized version definitions
# shellcheck disable=SC1091
source "/tmp/versions.sh"
MACHINE=$(uname -m)

echo "Installing Docker ${DOCKER_VERSION} from official Docker repository..."
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo sed -i 's/$releasever/9/g' /etc/yum.repos.d/docker-ce.repo
sudo dnf install -yq "docker-ce-${DOCKER_VERSION}" "docker-ce-cli-${DOCKER_VERSION}" containerd.io
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

echo "Verifying Docker components..."
docker --version
docker buildx version
docker compose version

echo "Making docker compose compatible w/ docker-compose v1..."
DOCKER_CLI_DIR=/usr/libexec/docker/cli-plugins
sudo ln -s "${DOCKER_CLI_DIR}/docker-compose" /usr/bin/docker-compose
sudo cp /tmp/conf/bin/docker-compose /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
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
sudo dnf install -y amazon-ecr-credential-helper
