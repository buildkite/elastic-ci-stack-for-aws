#!/bin/bash
set -euo pipefail

FROM="$1"
TO="$2"

case "$FROM" in
s3://*)
  exec aws s3 cp "$FROM" "$TO"
  ;;
*)
  exec curl -Lfs -o "$TO" "$FROM"
  ;;
esac
