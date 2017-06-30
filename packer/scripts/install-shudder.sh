#!/bin/bash

set -eu -o pipefail

pip install shudder==0.1.0

sudo mkdir /etc/shudder
sudo cp /tmp/conf/shudder/conf/* /etc/shudder
sudo cp /tmp/conf/shudder/upstart/* /etc/init