#!/bin/bash
set -euxo pipefail

command -v bats || (
  apk add bats \
    --no-cache \
    --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ \
    --allow-untrusted
)

command -v aws || (
  pip install awscli
)