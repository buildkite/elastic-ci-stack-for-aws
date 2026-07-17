#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "/tmp/distro.sh"

echo "Installing cloudwatch agent..."
case "${OS_DISTRO}" in
amazonlinux2023)
  pkg_install amazon-cloudwatch-agent
  ;;
ubuntu2404)
  # The agent is not in Ubuntu's apt repos; fetch the .deb published by Amazon.
  case "$(uname -m)" in
  x86_64) CW_ARCH=amd64 ;;
  aarch64) CW_ARCH=arm64 ;;
  *)
    echo "Unsupported architecture for amazon-cloudwatch-agent" >&2
    exit 1
    ;;
  esac
  pushd "$(mktemp -d)"
  curl -sSL "https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/${CW_ARCH}/latest/amazon-cloudwatch-agent.deb" -o amazon-cloudwatch-agent.deb
  pkg_install_local ./amazon-cloudwatch-agent.deb
  popd
  ;;
esac

echo "CloudWatch agent installed. Configuration will be done in stack layer."
