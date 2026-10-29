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

# No network: validate certificate fixtures and local helper behavior.
docker run --rm -v "$PWD:/src:ro" -w /src python:3.12-bookworm \
  sh -c 'python3 -m unittest discover -s tests/trust -v && python3 -m unittest discover -s tests/instance-storage -v && python3 -m unittest discover -s tests/plugins -v'
