#!/bin/bash
set -euo pipefail

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log|logger -t user-data -s 2>/dev/console) 2>&1

# Mount instance storage if we can
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html

# Move docker root to the ephemeral device
if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" != "true" ]] ; then
  echo "Skipping mounting instance storage"
  exit 0
fi

#shellcheck disable=SC2207
devices=($(nvme list | grep "Amazon EC2 NVMe Instance Storage"| cut -f1 -d' '))

if [ -z "${devices[*]}" ]
then
  echo "No Instance Storage NVMe drives to mount" >&2
  exit 0
fi

if [[ "${#devices[@]}" -eq 1 ]] ; then
  echo "Mounting instance storage device directly" >&2
  logicalname="${devices[0]}"
elif [[ "${#devices[@]}" -gt 1 ]] ; then
  echo "Mounting instance storage devices using software RAID" >&2
  logicalname=/dev/md0

  mdadm \
    --create "$logicalname" \
    --level=0 \
    -c256 \
    --raid-devices="${#devices[@]}" "${devices[@]}"

  echo "DEVICE ${devices[*]}" > /etc/mdadm.conf

  mdadm --detail --scan >> /etc/mdadm.conf
  blockdev --setra 65536 "$logicalname"
fi

# Make an ext4 file system, [-F]orce creation, don’t TRIM at fs creation time
# (-E nodiscard)
echo "Formatting $logicalname as ext4" >&2
mkfs.ext4 -F -E nodiscard "$logicalname" > /dev/null

devicemount=/mnt/ephemeral

echo "Mounting $logicalname to $devicemount" >&2

fs_type="ext4"
mount_options="defaults,noatime"

mkdir -p "$devicemount"
mount -t "${fs_type}" -o "${mount_options}" "$logicalname" "$devicemount"

if [ ! -f /etc/fstab.backup ]; then
  cp -rP /etc/fstab /etc/fstab.backup
  echo "$logicalname $devicemount    ${fs_type}  ${mount_options}  0 0" >> /etc/fstab
fi
