#!/bin/bash
set -euo pipefail

# SC1090: Can't follow non-constant source. Use a directive to specify location.

grep -rl '^#!/.*sh' . | while read -r file ; do
  [[ $file =~ \.git ]] && continue

  echo "Processing $file"
  shellcheck -e SC1090 -x -s bash "$file"
  echo -e "Ok.\n"
done