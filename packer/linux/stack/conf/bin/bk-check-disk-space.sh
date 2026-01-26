#!/bin/bash
set -euo pipefail

DISK_MIN_AVAILABLE=${DISK_MIN_AVAILABLE:-5242880} # 5GB
DISK_MIN_INODES=${DISK_MIN_INODES:-250000}        # docker needs lots

DOCKER_DIR="$(jq -r '."data-root" // "/var/lib/docker"' /etc/docker/daemon.json || true)"
if [[ -z "$DOCKER_DIR" ]]; then
  DOCKER_DIR="/var/lib/docker"
fi

disk_avail=$(df -k --output=avail "$DOCKER_DIR" | tail -n1)

echo "Disk space free: $(df -k -h --output=avail "$DOCKER_DIR" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $disk_avail -lt $DISK_MIN_AVAILABLE ]]; then
  # Convert kilobytes to human readable format
  disk_min_human=$(numfmt --to=iec-i --suffix=B --from-unit=1024 "${DISK_MIN_AVAILABLE}")
  disk_avail_human=$(numfmt --to=iec-i --suffix=B --from-unit=1024 "${disk_avail}")
  echo "Not enough disk space free: ${disk_avail_human} (${disk_avail}KB) available, cutoff is ${disk_min_human} (${DISK_MIN_AVAILABLE}KB) 🚨" >&2

  # Last resort for clearing space with build directory cleanup (if enabled)
  if [[ "${BUILDKITE_PURGE_BUILDS_ON_DISK_FULL:-false}" == "true" ]]; then
    echo "Purging all build directories to reclaim disk space..."
    rm -rf "${BUILDKITE_AGENT_BUILD_PATH:-/var/lib/buildkite-agent/builds}"/*
    disk_avail=$(df -k --output=avail "$DOCKER_DIR" | tail -n1)
    disk_avail_human=$(numfmt --to=iec-i --suffix=B --from-unit=1024 "${disk_avail}")
    echo "Disk space free after build purge: ${disk_avail_human} (${disk_avail}KB)"
    if [[ $disk_avail -ge $DISK_MIN_AVAILABLE ]]; then
      echo "Disk space sufficient after build purge. Continuing."
      exit 0
    else
      echo "Insufficient disk space remaining after build purge." >&2
      exit 1
    fi
  else
    echo "Insufficient disk space. Build purge not enabled." >&2
    exit 1
  fi
fi

inodes_avail=$(df -k --output=iavail "$DOCKER_DIR" | tail -n1)

echo "Inodes free: $(df -k -h --output=iavail "$DOCKER_DIR" | tail -n1 | sed -e 's/^[[:space:]]//')"

if [[ $inodes_avail -lt $DISK_MIN_INODES ]]; then
  echo "Not enough inodes free: ${inodes_avail} available, cutoff is ${DISK_MIN_INODES} 🚨" >&2
  exit 1
fi
