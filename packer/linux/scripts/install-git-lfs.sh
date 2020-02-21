#!/bin/bash

GIT_LFS_RELEASE="2.10.0"

echo "Installing git lfs ${GIT_LFS_RELEASE}..."
curl -Lsf -o git-lfs.tgz https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_RELEASE}/git-lfs-linux-amd64-v${GIT_LFS_RELEASE}.tar.gz
mkdir git-lfs
tar -xvzf git-lfs.tgz -C git-lfs
sudo chmod 755 git-lfs/git-lfs
sudo ./git-lfs/install.sh
rm -rf git-lfs.tgz git-lfs/
