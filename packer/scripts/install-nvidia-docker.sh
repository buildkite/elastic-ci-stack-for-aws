#!/bin/bash
set -eu -o pipefail

# nvidia driver
sudo yum install -y kernel-devel-$(uname -r) kernel-headers-$(uname -r) dkms

curl -Lsf -o cuda_toolkit.run http://us.download.nvidia.com/tesla/440.33.01/NVIDIA-Linux-x86_64-440.33.01.run
sudo sh cuda_toolkit.run --silent --dkms
rm cuda_toolkit.run

# nvidia-docker
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | sudo tee /etc/yum.repos.d/nvidia-docker.repo
sudo yum install -y nvidia-container-toolkit nvidia-container-runtime
