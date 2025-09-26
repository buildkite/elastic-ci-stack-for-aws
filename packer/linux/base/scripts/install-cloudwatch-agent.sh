#!/usr/bin/env bash
set -euo pipefail

echo "Installing cloudwatch agent..."
sudo dnf install -yq amazon-cloudwatch-agent

echo "CloudWatch agent installed. Configuration will be done in stack layer."
