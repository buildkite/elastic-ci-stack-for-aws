#!/bin/bash
set -euxo pipefail

# Mount instance storage if we can
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html

devicemount=/ephemeral
logicalname=/dev/md0
candidates=( '/dev/nvme1n1' )
devices=()

for candidate in "${candidates[@]}" ; do
  if [[ -b $candidate ]] ; then
    devices+=("$device")
  fi
done

if [[ "${#devices[@]}" -eq 1 ]] ; then
  mkfs.xfs -f "${devices[0]}" > /dev/null
  mount -t xfs -o noatime "${devices[0]}" "$devicemount"

  if [ ! -f /etc/fstab.backup ]; then
    cp -rP /etc/fstab /etc/fstab.backup
    echo "${devices[0]} $devicemount    xfs  defaults  0 0" >> /etc/fstab
  fi

elif [[ "${#devices[@]}" -gt 1 ]] ; then
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
