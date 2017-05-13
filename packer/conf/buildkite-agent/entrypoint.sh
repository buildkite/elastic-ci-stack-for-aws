#!/bin/bash
set -euxo pipefail

command -v aws || (
  pip install awscli
)