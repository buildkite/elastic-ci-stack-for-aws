#!/bin/bash
set -euo pipefail

grep -rl '^#!/.*sh' . | while read -r file; do
  [[ $file =~ \.git ]] && continue
  [[ $file =~ init\.d ]] && continue
  [[ $file =~ vendor ]] && continue
  [[ $file =~ plugins ]] && continue
  [[ $file =~ node_modules ]] && continue

  echo "Processing $file"
  docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d "$file"
  echo -e "Ok.\\n"
done

# Install the Linux bootstrap's JSON parser, then run credential-free checks.
docker run --rm -v "$PWD:/src:ro" -w /src python:3.12-bookworm \
  sh -ec '
    apt-get update -qq
    apt-get install -y --no-install-recommends jq
    python3 -m unittest discover -s tests/trust -v
    python3 -m unittest discover -s tests/instance-storage -v
    python3 -m unittest discover -s tests/linux -v
    python3 -m unittest discover -s tests/plugins -v
    python3 -m unittest discover -s tests/release-notes -v
    python3 -m unittest discover -s tests/cloudformation -v
  '
