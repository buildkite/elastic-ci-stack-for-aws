#!/bin/bash
apt-get install -y build-essential python-pip
pip install awscli
aws ec2 create-key-pair --key-name default