#!/bin/bash
set -euo pipefail

echo "Installing journald-cloudwatch-logs..."

# Install sj26 fork of journald-cloudwatch-logs
sudo curl -Lfs -o /usr/local/bin/journald-cloudwatch-logs https://github.com/sj26/journald-cloudwatch-logs/releases/download/v0.0.1-text/journald-cloudwatch-logs
sudo chmod +x /usr/local/bin/journald-cloudwatch-logs
sudo mkdir -p /var/lib/journald-cloudwatch-logs
sudo cp /tmp/conf/journald-cloudwatch-logs/journald-cloudwatch-logs.conf /etc/journald-cloudwatch-logs.conf

# Setup systemd
sudo cp /tmp/conf/journald-cloudwatch-logs/journald-cloudwatch-logs.service /etc/systemd/system/journald-cloudwatch-logs.service

echo "Configure journald-cloudwatch-logs to run on startup..."
sudo systemctl enable journald-cloudwatch-logs.service
