#!/bin/bash
# Distro abstraction for Linux packer builds.
# Sourced by install scripts alongside versions.sh. Reads OS_DISTRO (set by the
# packer shell provisioners) and exposes package-manager verbs and per-distro
# facts so the shared install logic stays distro-agnostic.

OS_DISTRO="${OS_DISTRO:-amazonlinux2023}"
export OS_DISTRO

case "${OS_DISTRO}" in
amazonlinux2023)
  LOGIN_USER="ec2-user"
  # rsyslog/RHEL log locations for the CloudWatch agent config
  CW_SYSLOG_PATH="/var/log/messages"
  CW_AUTHLOG_PATH="/var/log/secure"

  pkg_update() { sudo dnf update -yq; }
  pkg_install() { sudo dnf install -yq "$@"; }
  pkg_install_local() { sudo dnf install -y "$@"; }
  pkg_clean() { sudo dnf clean all; }
  ;;
ubuntu2404)
  LOGIN_USER="ubuntu"
  CW_SYSLOG_PATH="/var/log/syslog"
  CW_AUTHLOG_PATH="/var/log/auth.log"

  # apt can 404 on a package version when ports.ubuntu.com rotates a security
  # update between `apt-get update` and the fetch: the index lists a version the
  # pool has already purged. A plain URL retry cannot help (the file is gone), so
  # refresh the index (which then lists the version that exists) and retry.
  _apt_install() {
    local attempt
    for attempt in 1 2 3; do
      if sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq "$@"; then
        return 0
      fi
      if [ "${attempt}" -lt 3 ]; then
        echo "apt-get install failed (attempt ${attempt}/3); refreshing index and retrying..." >&2
        sudo apt-get update -yq || true
        sleep $((attempt * 5))
      fi
    done
    echo "apt-get install failed after 3 attempts" >&2
    return 1
  }

  pkg_update() { sudo apt-get update -yq; }
  pkg_install() { _apt_install "$@"; }
  # apt resolves dependencies for a local .deb path when prefixed with ./
  pkg_install_local() { _apt_install "$@"; }
  pkg_clean() { sudo apt-get clean; }
  ;;
*)
  echo "Unsupported OS_DISTRO: ${OS_DISTRO}" >&2
  exit 1
  ;;
esac

export LOGIN_USER CW_SYSLOG_PATH CW_AUTHLOG_PATH
