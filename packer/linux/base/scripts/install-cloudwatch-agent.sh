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
  # The agent is not in Ubuntu's apt repos; fetch the .deb published by Amazon
  # and verify its GPG signature before installing.
  case "$(uname -m)" in
  x86_64) CW_ARCH=amd64 ;;
  aarch64) CW_ARCH=arm64 ;;
  *)
    echo "Unsupported architecture for amazon-cloudwatch-agent" >&2
    exit 1
    ;;
  esac

  # AWS's documented signing key fingerprint for the CloudWatch agent, pinned as
  # the trust anchor: the key fetched below must match it, so a tampered bucket
  # cannot substitute a different key. AWS signs every agent version with this
  # key, so it does not change between releases; a key rotation fails here loudly.
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/verify-CloudWatch-Agent-Package-Signature.html
  CW_KEY_FINGERPRINT="937616F3450B7D806CBD9725D58167303B789C72"
  CW_BASE="https://amazoncloudwatch-agent.s3.amazonaws.com"

  workdir="$(mktemp -d)"
  pushd "$workdir"

  curl -fsSL "${CW_BASE}/assets/amazon-cloudwatch-agent.gpg" -o amazon-cloudwatch-agent.gpg
  curl -fsSL "${CW_BASE}/ubuntu/${CW_ARCH}/latest/amazon-cloudwatch-agent.deb" -o amazon-cloudwatch-agent.deb
  curl -fsSL "${CW_BASE}/ubuntu/${CW_ARCH}/latest/amazon-cloudwatch-agent.deb.sig" -o amazon-cloudwatch-agent.deb.sig

  # Import the key into an isolated keyring and confirm its fingerprint before
  # trusting it to verify the package signature.
  export GNUPGHOME="${workdir}/gnupg"
  mkdir -p "$GNUPGHOME"
  chmod 700 "$GNUPGHOME"
  gpg --batch --import amazon-cloudwatch-agent.gpg
  if ! gpg --batch --with-colons --fingerprint \
    | awk -F: '/^fpr:/ { print $10 }' \
    | grep -qx "$CW_KEY_FINGERPRINT"; then
    echo "CloudWatch agent GPG key fingerprint mismatch; refusing to install" >&2
    exit 1
  fi
  gpg --batch --verify amazon-cloudwatch-agent.deb.sig amazon-cloudwatch-agent.deb

  pkg_install_local ./amazon-cloudwatch-agent.deb

  popd
  unset GNUPGHOME
  rm -rf "$workdir"
  ;;
esac

echo "CloudWatch agent installed. Configuration will be done in stack layer."
