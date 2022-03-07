#!/usr/bin/env bash

# Clean up the cloud-init that was run on this machine (the one that packer takes a snapshot of to create the AMI)
# If cloud-init stuff gets left over in the AMI, it can cause the machine launching the AMI to not do cloud-init

sudo cloud-init clean
sudo mkdir -p /etc/systemd/system/cloud-init-local.service.d
sudo touch /etc/systemd/system/cloud-init-local.service.d/skip.conf
