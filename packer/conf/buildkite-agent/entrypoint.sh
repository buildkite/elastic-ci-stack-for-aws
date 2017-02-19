#!/bin/bash
set -euxo pipefail

command -v bats || (
  curl -O https://ghostbar.github.io/alpine-pkg-bats/v3.2/pkgs/x86_64/bats-0.4.0-r0.apk
  apk add --allow-untrusted bats-0.4.0-r0.apk
)

command -v aws || (
  pip install awscli
)