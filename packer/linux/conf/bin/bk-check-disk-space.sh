#!/bin/bash
set -euo pipefail

DISK_MIN_AVAILABLE=${DISK_MIN_AVAILABLE:-5242880} # 5GB
DISK_MIN_INODES=${DISK_MIN_INODES:-250000}        # docker needs lots

DOCKER_DIR="$(jq -r '."data-root" // "/var/lib/docker"' /etc/docker/daemon.json)"

disk_avail=$(df -k --output=avail "$DOCKER_DIR" | tail -n1)

echo "Disk space free: $(df -k -h --output=avail "$DOCKER_DIR" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $disk_avail -lt $DISK_MIN_AVAILABLE ]]; then
  # Convert kilobytes to human readable format
  disk_min_human=$(numfmt --to=iec-i --suffix=B --from-unit=1024 "${DISK_MIN_AVAILABLE}")
  disk_avail_human=$(numfmt --to=iec-i --suffix=B --from-unit=1024 "${disk_avail}")
  echo "Not enough disk space free: ${disk_avail_human} (${disk_avail}KB) available, cutoff is ${disk_min_human} (${DISK_MIN_AVAILABLE}KB) 🚨" >&2
  exit 1
fi

inodes_avail=$(df -k --output=iavail "$DOCKER_DIR" | tail -n1)

echo "Inodes free: $(df -k -h --output=iavail "$DOCKER_DIR" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $inodes_avail -lt $DISK_MIN_INODES ]]; then
  echo "Not enough inodes free: ${inodes_avail} available, cutoff is ${DISK_MIN_INODES} 🚨" >&2
  exit 1
fi
