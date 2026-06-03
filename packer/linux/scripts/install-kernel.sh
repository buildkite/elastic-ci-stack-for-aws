#!/usr/bin/env bash
set -euo pipefail

# Ensures the baked AMI boots a kernel6.12 that contains the fixes for the
# local privilege-escalation CVEs CVE-2026-31431, CVE-2026-43284 and
# CVE-2026-43500 (Amazon Linux 2023 ALAS). Building from the latest AL2023
# minimal image usually already carries a fixed kernel, but this step makes the
# guarantee explicit and fails the build if it is ever not met, so an unpatched
# image can never ship.

# Minimum kernel6.12 version (VERSION-RELEASE) that carries the fixes.
MIN_KERNEL="6.12.80-106.156"

# Pinned AL2023 release snapshot that carries the fixed kernel
# (kernel6.12-6.12.83-113.160). Pinning keeps the build reproducible; bump this
# when a newer fixed snapshot is required.
RELEASEVER="2023.11.20260509"

ARCH="$(uname -m)"

echo "Installing patched kernel6.12 and matching modules from AL2023 ${RELEASEVER}..."
# Pull from a pinned AL2023 snapshot so the security fix is available even if
# this build's base AMI is pinned to an older snapshot, and so the result is
# reproducible. Installing the kernel and its module/header/devel packages
# together keeps them at a consistent version.
sudo dnf install -yq --releasever="${RELEASEVER}" \
  kernel6.12 \
  kernel6.12-modules-extra \
  kernel6.12-headers \
  kernel6.12-devel

# Resolve the newest installed kernel6.12 from /boot so the grubby path and the
# version gate operate on the exact kernel that will boot.
NEWEST_VMLINUZ="$(ls -1 /boot/vmlinuz-6.12.* | sort -V | tail -1)"
NEWEST_KERNEL="$(basename "$NEWEST_VMLINUZ" | sed 's/^vmlinuz-//')"
echo "Newest installed kernel6.12: ${NEWEST_KERNEL}"

# Compare only the numeric VERSION-RELEASE (strip the .amzn2023.<arch> suffix).
INSTALLED_VR="$(echo "$NEWEST_KERNEL" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+\.[0-9]+')"
if [ "$(printf '%s\n%s\n' "$MIN_KERNEL" "$INSTALLED_VR" | sort -V | head -1)" != "$MIN_KERNEL" ]; then
  echo "ERROR: installed kernel6.12 ${INSTALLED_VR} is older than the required ${MIN_KERNEL}" >&2
  echo "Refusing to build an AMI with an unpatched kernel." >&2
  exit 1
fi

echo "Setting ${NEWEST_VMLINUZ} as the default boot kernel..."
sudo grubby --set-default "$NEWEST_VMLINUZ"
echo "Default boot kernel is now:"
sudo grubby --default-kernel

# Remove older, vulnerable kernel6.12 builds so they cannot be selected at boot.
# The currently running build kernel is never the patched one we just installed,
# so skip removing whatever is running to avoid breaking the rest of the build.
RUNNING_VR="$(uname -r | sed 's/\.amzn2023.*$//')"
for vr in $(rpm -q kernel6.12 --qf '%{VERSION}-%{RELEASE}\n' | sed 's/\.amzn2023$//' | sort -V | head -n -1); do
  if [ "$vr" = "$RUNNING_VR" ]; then
    echo "Skipping removal of the running kernel ${vr}"
    continue
  fi
  echo "Removing old kernel6.12 ${vr}"
  sudo dnf remove -yq "kernel6.12-${vr}" || true
done
