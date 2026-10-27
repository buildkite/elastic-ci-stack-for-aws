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

# Replace mappings atomically so Docker never reads a truncated file during boot.
write_userns_mapping_file() {
  local destination="$1"
  local first_id="$2"
  local temporary_file

  temporary_file=$(mktemp "${destination}.XXXXXX")
  cp --attributes-only --preserve=all "$destination" "$temporary_file"
  printf 'buildkite-agent:%s:1\nbuildkite-agent:100000:65536\n' "$first_id" >"$temporary_file"
  mv "$temporary_file" "$destination"
}

if [[ "${DOCKER_USERNS_REMAP:-false}" == "true" ]]; then
  echo Configuring user namespace remapping...

  echo Writing subuid...
  write_userns_mapping_file /etc/subuid "$(id -u buildkite-agent)"

  echo Writing subgid...
  write_userns_mapping_file /etc/subgid "$(getent group docker | awk -F: '{print $3}')"

  cat <<<"$(jq '."userns-remap"="buildkite-agent"' /etc/docker/daemon.json)" >/etc/docker/daemon.json
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
      --arg pool1 "${DOCKER_IPV4_ADDRESS_POOL_1:-172.17.0.0/12}" \
      --arg pool2 "${DOCKER_IPV4_ADDRESS_POOL_2:-192.168.0.0/16}" \
      '."default-address-pools"=[{"base":$pool1,"size":20},{"base":$pool2,"size":24}]' \
      /etc/docker/daemon.json
  )" >/etc/docker/daemon.json
elif [[ "${DOCKER_NETWORKING_PROTOCOL}" == "dualstack" ]]; then
  # Using v6 inside containers requires DOCKER_EXPERIMENTAL. This is configured
  # further down
  DOCKER_EXPERIMENTAL=true
  cat <<<"$(
    jq \
      --arg pool1 "${DOCKER_IPV4_ADDRESS_POOL_1:-172.17.0.0/12}" \
      --arg pool2 "${DOCKER_IPV4_ADDRESS_POOL_2:-192.168.0.0/16}" \
      --arg pool6 "${DOCKER_IPV6_ADDRESS_POOL:-2001:db8:2::/104}" \
      --arg cidrv6 "${DOCKER_FIXED_CIDR_V6:-2001:db8:1::/64}" \
      '.ipv6=true | ."fixed-cidr-v6"=$cidrv6 | .ip6tables=true | ."default-address-pools"=[{"base":$pool1,"size":20},{"base":$pool2,"size":24},{"base":$pool6,"size":112}]' \
      /etc/docker/daemon.json
  )" >/etc/docker/daemon.json
else
  # docker 25.0 doesn't support ipv6 only, so we don't support it either
  true
fi

# Configure fixed-cidr for IPv4 if provided (applies to both ipv4 and dualstack modes)
if [[ -n "${DOCKER_FIXED_CIDR_V4:-}" ]]; then
  echo "Configuring Docker fixed-cidr (IPv4): ${DOCKER_FIXED_CIDR_V4}"
  cat <<<"$(
    jq \
      --arg cidr "${DOCKER_FIXED_CIDR_V4}" \
      '."fixed-cidr"=$cidr' \
      /etc/docker/daemon.json
  )" >/etc/docker/daemon.json
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

# docker-binfmt can dependency-fail if Docker's initial boot start races with this configuration.
# Starting it here is a no-op when it is already active and retries it after Docker recovers.
echo Starting docker-binfmt...
systemctl start docker-binfmt.service
