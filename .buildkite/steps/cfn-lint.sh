#!/bin/bash
set -euo pipefail

echo "--- Installing cfn-lint"
pip install -q cfn-lint==1.36.0

echo "--- Running cfn-lint on templates in templates/"
# cfn-lint will scan all *.json, *.yaml, *.yml, *.template files in the directory and subdirectories.
/var/lib/buildkite-agent/.local/bin/cfn-lint templates/*
