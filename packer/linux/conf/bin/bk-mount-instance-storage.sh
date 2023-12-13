#!/usr/bin/env bash

set -Eeuo pipefail

on_error() {
  local exit_code="$?"
  local error_line="$1"

  echo "${BASH_SOURCE[0]} errored with exit code ${exit_code} on line ${error_line}."
  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

on_exit() {
  echo "${BASH_SOURCE[0]} completed successfully."
}

trap '[[ $? = 0 ]] && on_exit' EXIT

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting ${BASH_SOURCE[0]}..."

if [[ "${BUILDKITE_MOUNT_TMPFS_AT_TMP:-true}" != "true" ]]; then
  echo "Disabling automatic mount of tmpfs at /tmp"

  # "It is possible to disable the automatic mounting [...]
  # You may disable them simply by masking them:"
  # -- https://www.freedesktop.org/wiki/Software/systemd/APIFileSystems/
  systemctl mask --now tmp.mount
fi

# Mount instance storage if we can
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html

if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" != "true" ]]; then
  echo Skipped mounting instance storage.
  exit 0
fi

echo Mounting instance storage...

#shellcheck disable=SC2207
devices=($(nvme list | grep "Amazon EC2 NVMe Instance Storage" | cut -f1 -d' ' || true))
if [[ -z "${devices[*]}" ]]; then
  echo No NVMe drives to mount.
  echo Please check that your instance type supports instance storage.
  exit 0
fi

echo "Found NVMe devices: ${devices[*]}."

if [[ "${#devices[@]}" -eq 1 ]]; then
  echo Mounting instance storage device directly...
  logicalname="${devices[0]}"
elif [[ "${#devices[@]}" -gt 1 ]]; then
  echo Mounting instance storage devices using software RAID...
  logicalname=/dev/md0

  mdadm \
    --create "$logicalname" \
    --level=0 \
    -c256 \
    --raid-devices="${#devices[@]}" "${devices[@]}"
  echo "Mounted ${devices[*]} to $logicalname."

  echo "DEVICE ${devices[*]}" >/etc/mdadm.conf
  echo Created /etc/mdadm.conf:
  cat /etc/mdadm.conf

  mdadm --detail --scan >>/etc/mdadm.conf
  echo Updated /etc/mdadm.conf:
  cat /etc/mdadm.conf

  echo Setting readahead to 64k...
  blockdev --setra 65536 "$logicalname"
else
  echo Expected at least one nvme device, found: "${devices[*]}"
  echo
  echo This error is unexpected. Please contact support@buildkite.com.
  exit 1
fi

echo "Formatting $logicalname as ext4..."
# Make an ext4 file system, [-F]orce creation, don’t TRIM at fs creation time (-E nodiscard)
mkfs.ext4 -F -E nodiscard "$logicalname" >/dev/null

devicemount=/mnt/ephemeral
echo "Mounting $logicalname to $devicemount..."
fs_type="ext4"
mount_options="defaults,noatime"

mkdir -p "$devicemount"
mount -t "$fs_type" -o "$mount_options" "$logicalname" "$devicemount"

if [[ ! -f /etc/fstab.backup ]]; then
  echo Backing up /etc/fstab to /etc/fstab.backup...
  cp -rP /etc/fstab /etc/fstab.backup

  fstab_line="$logicalname $devicemount    ${fs_type}  ${mount_options}  0 0"
  echo "Appending $fstab_line to /etc/fstab..."
  echo "$fstab_line" >>/etc/fstab

  echo Appened to /etc/fstab:
  cat /etc/fstab
else
  echo /etc/fstab.backup already exists. Not modifying /etc/fstab:
  cat /etc/fstab
fi
