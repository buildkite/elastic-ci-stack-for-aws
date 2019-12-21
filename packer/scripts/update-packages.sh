#!/bin/bash
set -eu -o pipefail

echo "Updating core packages"
sudo yum update -y

echo "Reboot"
sudo reboot
