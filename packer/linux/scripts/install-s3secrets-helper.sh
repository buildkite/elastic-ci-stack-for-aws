#!/bin/bash
set -eu -o pipefail

S3_SECRETS_HELPER_VERSION=2.1.6

MACHINE="$(uname -m)"

case "${MACHINE}" in
	x86_64)    ARCH=amd64;;
	aarch64)   ARCH=arm64;;
esac

echo "Downloading s3-secrets-helper..."
sudo curl -Lsf -o /usr/local/bin/s3secrets-helper \
	"https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/releases/download/v${S3_SECRETS_HELPER_VERSION}/s3secrets-helper-linux-${ARCH}"
sudo chmod +x /usr/local/bin/s3secrets-helper
