#!/usr/bin/env bash
set -euo pipefail
for arch in amd64 arm64; do
  GOOS=linux GOARCH="${arch}" go build -v -o "build/fix-perms-linux-${arch}" ./internal/fixperms
done
