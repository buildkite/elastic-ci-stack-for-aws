#!/bin/bash

set -Eeufo pipefail

GIT_LFS_VERSION=3.3.0

MACHINE=$(uname -m)

case "${MACHINE}" in
	x86_64)    ARCH=amd64;;
	aarch64)   ARCH=arm64;;
	*)         ARCH=unknown;;
esac

echo "Installing git lfs ${GIT_LFS_VERSION}..."
pushd "$(mktemp -d)"
curl -sSL https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${ARCH}-v${GIT_LFS_VERSION}.tar.gz | tar xz
sudo git-lfs-${GIT_LFS_VERSION}/install.sh
popd
