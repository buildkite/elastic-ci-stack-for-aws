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

  pkg_update() { sudo apt-get update -yq; }
  pkg_install() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq "$@"; }
  # apt resolves dependencies for a local .deb path when prefixed with ./
  pkg_install_local() { sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq "$@"; }
  pkg_clean() { sudo apt-get clean; }
  ;;
*)
  echo "Unsupported OS_DISTRO: ${OS_DISTRO}" >&2
  exit 1
  ;;
esac

export LOGIN_USER CW_SYSLOG_PATH CW_AUTHLOG_PATH
