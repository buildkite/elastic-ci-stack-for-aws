#!/bin/bash
set -euo pipefail

grep -rl '^#!/.*sh' . | while read -r file ; do
  [[ $file =~ \.git ]] && continue
  [[ $file =~ init\.d ]] && continue

  echo "Processing $file"
  shellcheck -x -s bash "$file"
  echo -e "Ok.\n"
done