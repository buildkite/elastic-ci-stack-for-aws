#!/usr/bin/env bash

set -Eeuo pipefail

SHFMT=".buildkite/scripts/shfmt"

# ignore plugins - it contains submodules
"$SHFMT" --find . \
  | grep -v '^plugins/' \
  | xargs "$SHFMT" --diff --binary-next-line --indent 2
