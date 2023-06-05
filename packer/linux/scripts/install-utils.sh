#!/usr/bin/env bash
set -euo pipefail

case $(uname -m) in
  x86_64)    ARCH=amd64;;
  aarch64)   ARCH=arm64;;
  *)         ARCH=unknown;;
esac

echo Updating core packages
sudo yum update -yq

echo Installing utils...
sudo yum install -yq \
  aws-cfn-bootstrap \
  awscli-2 \
  git \
  jq \
  nvme-cli \
  pigz \
  python3 \
  python3-pip \
  python3-setuptools \
  unzip \
  zip

SESSION_MANAGER_PLUGIN_VERSION=1.2.30.0
echo "Installing session-manager-plugin $SESSION_MANAGER_PLUGIN_VERSION..."
sudo yum install -yq "https://s3.amazonaws.com/session-manager-downloads/plugin/$SESSION_MANAGER_PLUGIN_VERSION/linux_$ARCH/session-manager-plugin.rpm"

GIT_LFS_VERSION=3.3.0
echo "Installing git lfs ${GIT_LFS_VERSION}..."
pushd "$(mktemp -d)"
curl -sSL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${ARCH}-v${GIT_LFS_VERSION}.tar.gz | tar xz
sudo git-lfs-${GIT_LFS_VERSION}/install.sh
popd

# See https://github.com/goss-org/goss/releases for release versions
GOSS_VERSION=v0.3.23
echo "Installing goss $GOSS_VERSION for system validation..."
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${ARCH}" -o /usr/local/bin/goss
sudo chmod +rx /usr/local/bin/goss
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/dgoss" -o /usr/local/bin/dgoss
sudo chmod +rx /usr/local/bin/dgoss
