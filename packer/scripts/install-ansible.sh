#!/bin/bash -ie

sudo yum -y groupinstall "Development Tools"
sudo yum install -y gcc-c++ patch readline readline-devel libffi-devel openssl-devel
sudo pip install ansible boto cryptography
