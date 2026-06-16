#!/usr/bin/env bash
set -euo pipefail

# The base AMI is pinned to the AL2023 kernel-6.18 minimal image line (see the
# amazon-ami data source in buildkite-ami.pkr.hcl). Kernel 6.18 satisfies
# SourceFS requirements: FUSE passthrough (6.9+) and io_uring (6.13+).
# This step updates 6.18 to the latest patched build and FAILS the build if the
# booting kernel is older than the minimum validated version, so an unpatched
# image can never ship.

# Minimum kernel6.18 version (VERSION-RELEASE) that carries the fixes.
MIN_KERNEL="6.18.30-61.116"

echo "Updating kernel6.18 to the latest patched build..."
# Use `update`, not `install`: update only ever moves forward within the already
# installed 6.18 line and never crosses to a different kernel line, so it cannot
# try to remove the protected running kernel.
sudo dnf update -y kernel6.18

# Resolve the newest installed kernel6.18 from /boot so the grubby path and the
# version gate operate on the exact kernel that will boot.
NEWEST_VMLINUZ="$(ls -1 /boot/vmlinuz-6.18.* | sort -V | tail -1)"
NEWEST_KERNEL="$(basename "$NEWEST_VMLINUZ" | sed 's/^vmlinuz-//')"
echo "Newest installed kernel6.18: ${NEWEST_KERNEL}"

# Compare only the numeric VERSION-RELEASE (strip the .amzn2023.<arch> suffix).
INSTALLED_VR="$(echo "$NEWEST_KERNEL" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+')"
if [ "$(printf '%s\n%s\n' "$MIN_KERNEL" "$INSTALLED_VR" | sort -V | head -1)" != "$MIN_KERNEL" ]; then
  echo "ERROR: installed kernel6.18 ${INSTALLED_VR} is older than the required ${MIN_KERNEL}" >&2
  echo "Refusing to build an AMI with an unpatched kernel." >&2
  exit 1
fi

echo "Setting ${NEWEST_VMLINUZ} as the default boot kernel..."
sudo grubby --set-default "$NEWEST_VMLINUZ"
echo "Default boot kernel is now:"
sudo grubby --default-kernel
