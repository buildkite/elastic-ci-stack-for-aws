#!/bin/bash
set -euo pipefail

timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

echo "# Last updated: ${timestamp}" >"packer/windows/.trigger-base-build"
echo "# Last updated: ${timestamp}" >"packer/linux/.trigger-base-build"

git add packer/windows/.trigger-base-build packer/linux/.trigger-base-build

echo "Base AMI rebuild triggers updated"
