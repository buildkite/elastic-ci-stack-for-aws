#!/bin/bash
set -euo pipefail

echo "--- Installing cfn-lint"
python3.12 -m pip install -q cfn-lint==1.51.4

echo "--- Running cfn-lint on templates in templates/"
# cfn-lint will scan all *.json, *.yaml, *.yml, *.template files in the directory and subdirectories.
/var/lib/buildkite-agent/.local/bin/cfn-lint templates/*
