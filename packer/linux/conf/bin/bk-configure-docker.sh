#!/usr/bin/env bash
# shellcheck disable=SC2094

set -Eeuo pipefail

on_error() {
  local exit_code="$?"
  local error_line="$1"

  echo "${BASH_SOURCE[0]} errored with exit code ${exit_code} on line ${error_line}."
  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

on_exit() {
  echo "${BASH_SOURCE[0]} completed successfully."
}

trap '[[ $? = 0 ]] && on_exit' EXIT

## Configure docker before system starts

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting ${BASH_SOURCE[0]}..."

echo Sourcing /usr/local/lib/bk-configure-docker.sh...
echo This file is written by the scripts in packer/scripts.
echo Note that the path is /usr/local/lib, not /usr/local/bin.
echo Contents of /usr/local/lib/bk-configure-docker.sh:
cat /usr/local/lib/bk-configure-docker.sh
# shellcheck disable=SC1091
source /usr/local/lib/bk-configure-docker.sh

echo Installing qemu binfmt for multiarch...
if ! docker run \
  --privileged \
  --userns=host \
  --pull=never \
  --rm \
  "tonistiigi/binfmt@${QEMU_BINFMT_DIGEST}" \
  --install all; then
  echo Failed to install binfmt.
  echo Avaliable docker images:
  docker image ls
  exit 1
fi

if [[ "${DOCKER_USERNS_REMAP:-false}" == "true" ]]; then
  echo Configuring user namespace remapping...

  cat <<<"$(jq '."userns-remap"="buildkite-agent"' /etc/docker/daemon.json)" >/etc/docker/daemon.json

  echo Writing subuid...
  cat <<EOF | tee /etc/subuid
buildkite-agent:$(id -u buildkite-agent):1
buildkite-agent:100000:65536
EOF

  echo Writing subgid...
  cat <<EOF | tee /etc/subgid
buildkite-agent:$(getent group docker | awk -F: '{print $3}'):1
buildkite-agent:100000:65536
EOF
else
  echo User namespace remapping not configured.
fi

if [[ "${DOCKER_EXPERIMENTAL:-false}" == "true" ]]; then
  echo Configuring experiment flag for docker daemon...
  cat <<<"$(jq '.experimental=true' /etc/docker/daemon.json)" >/etc/docker/daemon.json
else
  echo Experiment flag for docker daemon not configured.
fi

if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]]; then
  echo Creating docker root directory in instance storage...
  mkdir -p /mnt/ephemeral/docker
  echo Configuring docker root directory to be in instance storage...
  cat <<<"$(jq '."data-root"="/mnt/ephemeral/docker"' /etc/docker/daemon.json)" >/etc/docker/daemon.json
else
  echo Instance storage not configured.
fi

echo Customising docker IP address pools...
cat <<<"$(
  jq \
    '."default-address-pools"=[{"base":"172.17.0.0/12","size":20},{"base":"192.168.0.0/16","size":24}]' \
    /etc/docker/daemon.json
)" >/etc/docker/daemon.json

echo Cleaning up docker images...
systemctl start docker-low-disk-gc.service

echo Enabling docker-gc timers...
systemctl enable docker-gc.timer docker-low-disk-gc.timer

echo Restarting docker daemon...
systemctl restart docker
