#!/bin/bash

set -eu -o pipefail

echo "Installing zip utils..."
sudo yum update -y -q
sudo yum install -y zip unzip
