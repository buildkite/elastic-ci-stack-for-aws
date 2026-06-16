#!/usr/bin/env bash
set -eux

# 1. install can-utils
sudo dnf install -yq can-utils

# Install kernel modules for SocketCAN support
# Detect kernel major version and install matching packages
KERNEL_VERSION=$(uname -r)
KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1,2)

echo "Detected kernel version: $KERNEL_VERSION (major: $KERNEL_MAJOR)"

if [[ "$KERNEL_MAJOR" == "6.18" ]]; then
  sudo dnf install -y kernel6.18-modules-extra kernel6.18-headers kernel6.18-devel
elif [[ "$KERNEL_MAJOR" == "6.12" ]]; then
  # AL2023 with kernel 6.12 uses kernel6.12-* packages
  sudo dnf install -y kernel6.12-modules-extra kernel6.12-headers kernel6.12-devel
elif [[ "$KERNEL_MAJOR" == "6.1" ]]; then
  # AL2023 with kernel 6.1 uses kernel-* packages
  sudo dnf install -y kernel-modules-extra kernel-headers kernel-devel
else
  # Fallback: try generic package names
  sudo dnf install -y kernel-modules-extra kernel-headers kernel-devel || \
    echo "Warning: Could not install kernel packages for version $KERNEL_MAJOR"
fi

# Load vcan module if available for the current kernel, but don't fail if not
# (the module will be available after reboot with the installed kernel)
sudo modprobe vcan || echo "vcan module not available for current kernel, will be available after reboot"
