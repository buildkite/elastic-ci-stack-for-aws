#!/usr/bin/env bash
set -euo pipefail

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac

TEST_SPLITTER_VERSION=0.8.0
echo "Downloading test-splitter v${TEST_SPLITTER_VERSION}..."
sudo curl -Lsf -o /usr/bin/test-splitter \
  "https://github.com/buildkite/test-splitter/releases/download/v${TEST_SPLITTER_VERSION}/test-splitter_${TEST_SPLITTER_VERSION}_linux_${ARCH}"
sudo chmod +x /usr/bin/test-splitter
test-splitter --version
