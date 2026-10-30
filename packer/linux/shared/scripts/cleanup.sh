#!/usr/bin/env bash
set -euo pipefail

# Stack builds still stage assets in /tmp.
# shellcheck disable=SC1091
source "${STAGING_DIR:-/tmp}/distro.sh"

pkg_clean
