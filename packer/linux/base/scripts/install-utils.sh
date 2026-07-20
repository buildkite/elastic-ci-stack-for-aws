#!/usr/bin/env bash

set -euo pipefail

# Source centralized version definitions
# shellcheck disable=SC1091
source "/tmp/versions.sh"
# shellcheck disable=SC1091
source "/tmp/distro.sh"

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo Updating core packages
pkg_update

echo Installing utils...
# Packages available under the same name on both distros
pkg_install \
  git \
  jq \
  lsof \
  mdadm \
  nvme-cli \
  pigz \
  rsyslog \
  unzip \
  wget \
  zip

case "${OS_DISTRO}" in
amazonlinux2023)
  pkg_install \
    amazon-ssm-agent \
    aws-cfn-bootstrap \
    ec2-instance-connect \
    bind-utils \
    python \
    python-pip \
    python-setuptools \
    python3.11 \
    python3.11-pip \
    python3.12 \
    python3.12-pip \
    python3.13 \
    python3.13-pip \
    python3.14 \
    python3.14-pip

  sudo dnf -yq groupinstall "Development Tools"

  # Upgrade GPG to full version to support development tools like asdf
  # See https://github.com/buildkite/elastic-ci-stack-for-aws/issues/1402
  echo "Upgrading GPG from minimum to full version..."
  sudo dnf swap -yq gnupg2-minimal gnupg2-full

  sudo systemctl enable --now amazon-ssm-agent
  ;;
ubuntu2404)
  # Ubuntu ships Python 3.12 natively. The extra 3.11/3.13/3.14 interpreters
  # available on AL2023 are not packaged here and are intentionally omitted.
  pkg_install \
    dnsutils \
    build-essential \
    ec2-instance-connect \
    gnupg \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-venv \
    snapd

  # amazon-ssm-agent ships as a snap and is preinstalled on Canonical's AWS AMIs
  if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
    sudo snap install amazon-ssm-agent
  fi
  sudo systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service

  # cfn-signal (the only CFN helper this stack uses) is not packaged for Ubuntu,
  # so install it from Amazon's tarball. Source its Python dependencies from apt
  # rather than letting pip pull them from PyPI unpinned as root: with --no-deps
  # pip installs only aws-cfn-bootstrap itself. AWS publishes no signature or
  # versioned URL for the tarball, so the fetch trusts TLS to the AWS-owned
  # bucket (its documented install method).
  pkg_install python3-daemon python3-docutils python3-chevron
  sudo pip3 install --break-system-packages --no-deps \
    https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
  # cfn-hup's init script (init/ubuntu/cfn-hup) is intentionally not symlinked
  # into /etc/init.d: this stack runs cfn-signal only, never cfn-hup.
  ;;
esac

sudo systemctl enable --now rsyslog

echo "Installing AWS CLI v2 ${AWS_CLI_LINUX_VERSION}..."
pushd "$(mktemp -d -p /var/tmp)"
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
pushd "$(mktemp -d -p /var/tmp)"
curl -sSL https://github.com/git-lfs/git-lfs/releases/download/v"${GIT_LFS_VERSION}"/git-lfs-linux-"${ARCH}"-v"${GIT_LFS_VERSION}".tar.gz | tar xz
sudo git-lfs-"${GIT_LFS_VERSION}"/install.sh
popd

# goss is built from source and installed in the stack image (see
# install-buildkite-utils.sh), because we pin it to an unreleased commit.

echo "Adding authorized keys systemd units..."
sudo cp /tmp/conf/ssh/systemd/* /etc/systemd/system
