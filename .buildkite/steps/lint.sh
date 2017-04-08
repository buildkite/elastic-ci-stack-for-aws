#!/bin/bash
set -euo pipefail

grep -rl '^#!/.*sh' . | while read -r file ; do
  [[ $file =~ \.git ]] && continue
  [[ $file =~ init\.d ]] && continue
  [[ $file =~ vendor ]] && continue

  echo "Processing $file"
  docker run --rm -v "$PWD:/mnt" koalaman/shellcheck "$file"
  echo -e "Ok.\n"
done