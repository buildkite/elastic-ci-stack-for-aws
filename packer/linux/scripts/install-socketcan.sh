#!/usr/bin/env bash
set -eux

# 1. install can-utils
sudo dnf install -yq can-utils

sudo dnf install -y "kernel-modules-extra-$(uname -r)" \
                      "kernel-headers-$(uname -r)" \
                      "kernel-devel-$(uname -r)"

sudo dnf install -y "kernel-modules-extra-$(uname -r)" \
                      "kernel-headers-$(uname -r)" \
                      "kernel-devel-$(uname -r)"

sudo modprobe vcan
