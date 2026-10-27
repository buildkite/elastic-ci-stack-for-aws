#!/bin/bash
set -euo pipefail

grep -rl '^#!/.*sh' . | while read -r file; do
  [[ $file =~ \.git ]] && continue
  [[ $file =~ init\.d ]] && continue
  [[ $file =~ vendor ]] && continue
  [[ $file =~ plugins ]] && continue
  [[ $file =~ node_modules ]] && continue

  echo "Processing $file"
  docker run --rm -v "$PWD:/mnt" koalaman/shellcheck "$file"
  echo -e "Ok.\\n"
done

tests/linux/test-terminate-instance.sh

# No network: validate committed certificate fixtures and configuration invariants.
docker run --rm -v "$PWD:/src:ro" -w /src python:3.12-bookworm \
  python3 -m unittest discover -s tests/trust -v
