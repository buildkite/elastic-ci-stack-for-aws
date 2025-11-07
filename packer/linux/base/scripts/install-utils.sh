#!/usr/bin/env bash

set -euo pipefail

# Source centralized version definitions
# shellcheck source=packer/linux/shared/scripts/versions.sh
source "$(dirname "${BASH_SOURCE[0]}")/../../shared/scripts/versions.sh"

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

# Upgrade GPG to full version to support development tools like asdf
# See https://github.com/buildkite/elastic-ci-stack-for-aws/issues/1402
echo "Upgrading GPG from minimum to full version..."
sudo dnf swap -yq gnupg2-minimal gnupg2-full

sudo systemctl enable --now amazon-ssm-agent
sudo systemctl enable --now rsyslog

echo "Installing AWS CLI v2 ${AWS_CLI_LINUX_VERSION}..."
pushd "$(mktemp -d)"
case $(uname -m) in
x86_64)
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_LINUX_VERSION}.zip" -o "awscliv2.zip"
  ;;
aarch64)
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_LINUX_VERSION}.zip" -o "awscliv2.zip"
  ;;
*)
  echo "Unsupported architecture for AWS CLI v2"
  exit 1
  ;;
esac
unzip -qq awscliv2.zip
sudo ./aws/install
popd

echo "Installing git lfs ${GIT_LFS_VERSION}..."
pushd "$(mktemp -d)"
curl -sSL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${ARCH}-v${GIT_LFS_VERSION}.tar.gz | tar xz
sudo git-lfs-${GIT_LFS_VERSION}/install.sh
popd

# See https://github.com/goss-org/goss/releases for release versions
echo "Installing goss $GOSS_VERSION for system validation..."
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/goss-linux-${ARCH}" -o /usr/local/bin/goss
sudo chmod +rx /usr/local/bin/goss
sudo curl -L "https://github.com/goss-org/goss/releases/download/${GOSS_VERSION}/dgoss" -o /usr/local/bin/dgoss
sudo chmod +rx /usr/local/bin/dgoss

echo "Adding authorized keys systemd units..."
sudo cp /tmp/conf/ssh/systemd/* /etc/systemd/system
