#!/bin/bash
set -euo pipefail

# Usage:
# bk-check-disk-space.sh (min disk required) (min inodes required)
# min disk required can be either an amount of bytes, a pattern like 10G
# or 500M, or a percentage like 5%
# min inodes must be a number, default to 250,000

# Converts human-readable units like 1.43K and 120.3M to bytes
dehumanize() {
  awk '/[0-9][bB]?$/ {printf "%u\n", $1*1024}
       /[tT][bB]?$/  {printf "%u\n", $1*(1024*1024*1024)}
       /[gG][bB]?$/  {printf "%u\n", $1*(1024*1024)}
       /[mM][bB]?$/  {printf "%u\n", $1*(1024)}
       /[kK][bB]?$/  {printf "%u\n", $1*1}' <<< "$1"
}

min_available=${1:-5G}
docker_dir="/var/lib/docker/"

# First check the disk available

disk_avail=$(df -k --output=avail "$docker_dir" | tail -n1)
disk_avail_human=$(df -k -h --output=avail "$docker_dir" | tail -n1 | tr -d '[:space:]')
disk_used_pct=$(df -k --output=pcent "$docker_dir" | tail -n1 | tr -d '[:space:]' | tr -d '%')
disk_free_pct=$((100-disk_used_pct))

printf "Disk space free: %s (%s%%)\\n" "$disk_avail_human" "$disk_free_pct"

# Check if the min_available is a percentage
if [[ $min_available =~ \%$ ]] ; then
  if [[ $(echo "${disk_free_pct}<${min_available}" | sed 's/%//g' | bc) -gt 0 ]] ; then
    echo "Not enough disk space free, cutoff is ${min_available} 🚨" >&2
    exit 1
  fi
else
  if [[ $disk_avail -lt $(dehumanize "$min_available") ]]; then
    echo "Not enough disk space free, cutoff is ${min_available} 🚨" >&2
    exit 1
  fi
fi

# Next check inodes, these can be exhausted by docker build operations

inodes_min_available=${2:-250000}
inodes_avail=$(df -k --output=iavail "$docker_dir" | tail -n1 | tr -d '[:space:]')
inodes_avail_human=$(df -k -h --output=iavail "$docker_dir" | tail -n1 | tr -d '[:space:]')
inodes_used_pct=$(df -k --output=ipcent "$docker_dir" | tail -n1 | tr -d '[:space:]' | tr -d '%')
inodes_free_pct=$((100-inodes_used_pct))

printf "Inodes free: %s (%s%%)\\n" "$inodes_avail_human" "$inodes_free_pct"

if [[ $inodes_avail -lt $inodes_min_available ]]; then
  echo "Not enough inodes free, cutoff is ${inodes_min_available} 🚨" >&2
  exit 1
fi
