#!/bin/bash
set -euo pipefail

DISK_MIN_AVAILABLE=${DISK_MIN_AVAILABLE:-1048576} # 1GB
DISK_MIN_INODES=${DISK_MIN_INODES:-10000}

disk_avail=$(df -k --output=avail "$PWD" | tail -n1)

echo "Disk space free: $(df -k -h --output=avail "$PWD" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $disk_avail -lt $DISK_MIN_AVAILABLE ]]; then
  echo "Not enough disk space free, cutoff is ${DISK_MIN_AVAILABLE} 🚨" >&2
  return 1
fi

inodes_avail=$(df -k --output=iavail "$PWD" | tail -n1)

echo "Inodes free: $(df -k -h --output=iavail "$PWD" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $inodes_avail -lt $DISK_MIN_INODES ]]; then
  echo "Not enough inodes free, cutoff is ${DISK_MIN_INODES inodes} 🚨" >&2
  return 1
fi
