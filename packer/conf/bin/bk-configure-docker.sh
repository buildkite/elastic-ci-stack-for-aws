#!/bin/bash
set -euo pipefail

## Configures docker before system starts

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log|logger -t user-data -s 2>/dev/console) 2>&1

# Swap in the userns remap config
if [[ "${DOCKER_USERNS_REMAP:-false}" == "true" ]] ; then
	mv /etc/docker/daemon.userns-remap.json /etc/docker/daemon.json
else
  rm /etc/docker/daemon.userns-remap.json
fi
