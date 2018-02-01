#!/bin/bash
set -euo pipefail

DISK_MIN_AVAILABLE=${DISK_MIN_AVAILABLE:-1048576} # 1GB
DISK_MIN_INODES=${DISK_MIN_INODES:-10000}

disk_avail=$(df -k --output=avail "$PWD" | tail -n1)

if [[ $disk_avail -lt $DISK_MIN_AVAILABLE ]]; then
  echo "Not enough disk space free 🚨" >&2
  return 1
else
  echo "Disk space free: $disk_avail ✅"
fi

inodes_avail=$(df -k --output=iavail "$PWD" | tail -n1)

if [[ $inodes_avail -lt $DISK_MIN_INODES ]]; then
  echo "Not enough inodes free 🚨" >&2
  return 1
else
  echo "Inodes free: $inodes_avail ✅"
fi
