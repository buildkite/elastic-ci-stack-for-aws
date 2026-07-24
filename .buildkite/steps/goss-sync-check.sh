#!/bin/bash
set -euo pipefail

echo "--- Installing PyYAML"
python3.12 -m pip install -q pyyaml

echo "--- Checking goss.yaml / goss.ubuntu2404.yaml sync"
python3.12 .buildkite/scripts/check-goss-sync.py
