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

# One day we can auto-detect whether the instance is v4-only, dualstack or v6-only. To avoid a
# breaking change though, we'll default to ipv4 only and users can opt into v6 support. The elastic
# stack has always defaulted to v4-only so this ensures no breaking behaviour.
# v6-only is currently not an option because docker doesn't support it, but maybe one day....
echo Customising docker network configuration...

if [[ "${DOCKER_NETWORKING_PROTOCOL}" == "ipv4" ]]; then
  # This is the default
  cat <<<"$(
    jq \
      '."default-address-pools"=[{"base":"172.17.0.0/12","size":20},{"base":"192.168.0.0/16","size":24}]' \
      /etc/docker/daemon.json
  )" >/etc/docker/daemon.json
elif [[ "${DOCKER_NETWORKING_PROTOCOL}" == "dualstack" ]]; then
  # Using v6 inside containers requires DOCKER_EXPERIMENTAL. This is configured
  # further down
  DOCKER_EXPERIMENTAL=true
  cat <<<"$(
    jq \
      '.ipv6=true | ."fixed-cidr-v6"="2001:db8:1::/64" | .ip6tables=true | ."default-address-pools"=[{"base":"172.17.0.0/12","size":20},{"base":"192.168.0.0/16","size":24},{"base":"2001:db8:2::/104","size":112}]' \
      /etc/docker/daemon.json
  )" >/etc/docker/daemon.json
else
  # docker 25.0 doesn't support ipv6 only, so we don't support it either
  true
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

echo Cleaning up docker images...
systemctl start docker-low-disk-gc.service

echo Enabling docker-gc timers...
systemctl enable docker-gc.timer docker-low-disk-gc.timer

echo Restarting docker daemon...
systemctl restart docker
