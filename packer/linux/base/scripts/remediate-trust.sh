#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source /tmp/distro.sh

# https://emudhra.we-have-a-problem.com/ (20 October 2026).
# AL2023 repositories are release-locked, including on the fixed CIS source AMI.
# Updating within that old snapshot does not guarantee updated CA packages.
case "${OS_DISTRO}" in
amazonlinux2023)
  sudo dnf --releasever=latest upgrade -yq ca-certificates p11-kit p11-kit-trust
  sudo dnf --releasever=latest install -yq ca-certificates p11-kit-trust openssl python3
  # Persist explicit distrust even if a later package adds a root back.
  blocklist=/etc/pki/ca-trust/source/blacklist
  if [ -d /etc/pki/ca-trust/source/blocklist ]; then
    blocklist=/etc/pki/ca-trust/source/blocklist
  fi
  sudo mkdir -p "${blocklist}"
  sudo cp /tmp/trust/roots/*.crt "${blocklist}/"
  sudo update-ca-trust extract
  ;;
ubuntu2404)
  sudo apt-get update -yq
  pkg_install ca-certificates openssl python3
  version=$(dpkg-query -W -f='${Version}' ca-certificates)
  dpkg --compare-versions "${version}" ge 20260816ubuntu0.24.04.1 || {
    echo "Ubuntu ca-certificates is older than the eMudhra security fix: ${version}" >&2
    exit 1
  }
  sudo sed -i \
    -e 's|^mozilla/emSign_ECC_Root_CA_-_G3.crt$|!&|' \
    -e 's|^mozilla/Comodo_AAA_Services_root.crt$|!&|' \
    /etc/ca-certificates.conf
  sudo update-ca-certificates --fresh
  ;;
esac

# Fail closed if the effective TLS store still trusts any affected root.
python3 /tmp/trust/check-trust.py
sudo mkdir -p /usr/local/share/buildkite-trust
sudo cp -r /tmp/trust/. /usr/local/share/buildkite-trust/
