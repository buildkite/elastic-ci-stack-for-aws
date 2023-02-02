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

GIT_VERSION=2.39.1
echo "Installing git $GIT_VERSION"
sudo yum install -y rpm-build yum-utils
sudo amazon-linux-extras install epel -y

pushd "$(mktemp -d)"
yumdownloader --source git-2.38.1
rpm -ivh git-2.38.1-1.amzn2.0.1.src.rpm
popd

pushd "$HOME/rpmbuild/SOURCES"
curl -sSLOJ "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz"
curl -sSLOJ "https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.sign"
popd

pushd "$HOME/rpmbuild/SPECS"
# we don't want to build with docs, it pulls in a lot of dependencies we do not want
sed -i '/^%if %{with docs}$/,/^# endif with docs$/d' git.spec
# bump the version
sed -i 's/tarball_version 2.38.1/tarball_version '"${GIT_VERSION}"'/;s/Version:        2.38.1/Version:        '"${GIT_VERSION}/" git.spec
sudo yum-builddep -y git.spec
rpmbuild -ba --nocheck --nodeps --without docs --without tests git.spec
popd

pushd "$HOME/rpmbuild/RPMS"
sudo yum localinstall -y noarch/* "$(uname -m)"/*
popd

echo "Installing goss for system validation..."
curl -fsSL https://goss.rocks/install | GOSS_VER=v0.3.20 sudo sh
