#!/usr/bin/env bash
set -euo pipefail

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

echo "Installing bk elastic stack bin files..."
sudo chmod +x /tmp/conf/bin/bk-*
sudo mv /tmp/conf/bin/bk-* /usr/local/bin

echo "Installing fix-buildkite-agent-builds-permissions..."
sudo chmod +x "/tmp/build/fix-perms-linux-${ARCH}"
sudo mv "/tmp/build/fix-perms-linux-${ARCH}" /usr/bin/fix-buildkite-agent-builds-permissions

S3_SECRETS_HELPER_VERSION=2.1.6
echo "Downloading s3-secrets-helper ${S3_SECRETS_HELPER_VERSION}..."
sudo curl -Lsf -o /usr/local/bin/s3secrets-helper \
  "https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/releases/download/v${S3_SECRETS_HELPER_VERSION}/s3secrets-helper-linux-${ARCH}"
sudo chmod +x /usr/local/bin/s3secrets-helper

LIFECYCLED_VERSION=v3.3.0
echo "Installing lifecycled ${LIFECYCLED_VERSION}..."
sudo touch /etc/lifecycled
sudo curl -Lf -o /usr/bin/lifecycled \
  https://github.com/buildkite/lifecycled/releases/download/${LIFECYCLED_VERSION}/lifecycled-linux-${ARCH}
sudo chmod +x /usr/bin/lifecycled
sudo curl -Lf -o /etc/systemd/system/lifecycled.service \
  https://raw.githubusercontent.com/buildkite/lifecycled/${LIFECYCLED_VERSION}/init/systemd/lifecycled.unit

echo "Adding authorized keys systemd units..."
sudo cp /tmp/conf/ssh/systemd/* /etc/systemd/system
