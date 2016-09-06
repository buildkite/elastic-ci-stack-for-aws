#!/bin/bash

set -eu -o pipefail

sudo mkdir /etc/terminationd
sudo cp /tmp/conf/terminationd/bin/* /usr/bin
sudo cp /tmp/conf/terminationd/upstart/* /etc/init
