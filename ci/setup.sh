#!/bin/bash
apt-get install -y build-essential python-pip unzip ruby
pip install awscli
aws ec2 create-key-pair --key-name default
gem install bundler
wget https://releases.hashicorp.com/packer/0.8.6/packer_0.8.6_linux_amd64.zip
unzip packer_0.8.6_linux_amd64.zip -d /usr/local/bin/