#!/bin/bash
set -eu -o pipefail

echo "Updating core packages"
sudo yum update -y

echo "Updating awscli..."
sudo yum install -y python2-pip
sudo yum install -y python3-pip python3 python3-setuptools
sudo pip install --upgrade awscli
sudo pip install future
sudo pip3 install future

echo "Installing zip utils..."
sudo yum update -y -q
sudo yum install -y zip unzip git pigz

echo "Installing bk elastic stack bin files..."
sudo chmod +x /tmp/conf/bin/bk-*
sudo mv /tmp/conf/bin/bk-* /usr/local/bin

echo "Configuring awscli to use v4 signatures..."
sudo aws configure set s3.signature_version s3v4

# https://git-scm.com/book/en/v2/Getting-Started-Installing-Git#_installing_from_source
GIT_VERSION=2.39.1
echo "Installing git $GIT_VERSION from source"
sudo yum -y groupinstall "Development Tools"
pushd "$(mktemp -d)"
curl -sSL "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz" | tar xJ
pushd git-"$GIT_VERSION"
make configure
./configure --prefix=/usr
make all
sudo make install
git --version
sudo yum -y groupremove "Development Tools"
popd
popd

echo "Installing goss for system validation..."
curl -fsSL https://goss.rocks/install | GOSS_VER=v0.3.20 sudo sh
