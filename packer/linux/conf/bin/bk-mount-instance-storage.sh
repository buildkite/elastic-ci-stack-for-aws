#!/bin/bash
set -euxo pipefail

# Mount instance storage if we can
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html

# Move docker root to the ephemeral device
if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" != "true" ]] ; then
  echo "Skipping mounting instance storage"
  exit 0
fi

devicemount=/ephemeral
devices=($(sudo nvme list | grep "Amazon EC2 NVMe Instance Storage"| cut -f1 -d' '))

if [ -z "${devices[@]}" ]
then
  echo "No Instance Storage NVMe drives to mount" >&2
  exit 0
fi

mkdir -p "$devicemount"

if [[ "${#devices[@]}" -eq 1 ]] ; then
  # Make an ext4 file system, [-F]orce creation
  mkfs.ext4 -F -E nodiscard "${devices[0]}" > /dev/null
  mount -t ext4 -o noatime "${devices[0]}" "$devicemount"

  if [ ! -f /etc/fstab.backup ]; then
    cp -rP /etc/fstab /etc/fstab.backup
    echo "${devices[0]} $devicemount    ext4  defaults  0 0" >> /etc/fstab
  fi

elif [[ "${#devices[@]}" -gt 1 ]] ; then
  logicalname=/dev/md0
  yes | mdadm \
    --create "$logicalname" \
    --level=0 \
    -c256 \
    --raid-devices="${#devices[@]}" "${devices[@]}"

  echo \'DEVICE "${devices[*]}"\' > /etc/mdadm.conf

  mdadm --detail --scan >> /etc/mdadm.conf
  blockdev --setra 65536 "$logicalname"
  mkfs.xfs -f "$logicalname" > /dev/null
  mkdir -p "$devicemount"
  mount -t xfs -o noatime "$logicalname" "$devicemount"

  if [ ! -f /etc/fstab.backup ]; then
      cp -rP /etc/fstab /etc/fstab.backup
      echo "$logicalname $devicemount    xfs  defaults  0 0" >> /etc/fstab
  fi
fi
