#!/usr/bin/env bash

set -euo pipefail

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo Updating core packages
sudo dnf update -yq

echo Installing utils...
sudo dnf install -yq \
  amazon-ssm-agent \
  aws-cfn-bootstrap \
  awscli-2 \
  ec2-instance-connect \
  git \
  jq \
  mdadm \
  nvme-cli \
  pigz \
  python \
  python-pip \
  python-setuptools \
  unzip \
  wget \
  zip

# These are some tools that are no longer installed on AL2023 by default
# there may be more modern replacements for these, so they may dissapper
# in a future version of Amazon Linux
sudo dnf install -yq \
  bind-utils \
  lsof \
  rsyslog

sudo dnf -yq groupinstall "Development Tools"

sudo systemctl enable --now amazon-ssm-agent
sudo systemctl enable --now rsyslog

GIT_LFS_VERSION=3.4.0
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
