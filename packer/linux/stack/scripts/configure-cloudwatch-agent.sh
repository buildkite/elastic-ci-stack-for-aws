#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "/tmp/distro.sh"

echo "Configuring cloudwatch agent..."

echo "Adding amazon-cloudwatch-agent config..."
sudo cp /tmp/conf/cloudwatch-agent/amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# The syslog/auth log locations differ by distro. On AL2023 these substitutions
# are a no-op (the config already uses the RHEL paths). Each path appears only
# as a file_path value, so a global replace is safe.
sudo sed -i \
  -e "s#/var/log/messages#${CW_SYSLOG_PATH}#g" \
  -e "s#/var/log/secure#${CW_AUTHLOG_PATH}#g" \
  /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Configuring amazon-cloudwatch-agent to start at boot"
sudo systemctl enable amazon-cloudwatch-agent

# These will send some systemctl service logs (like the buildkite agent and docker) to logfiles
echo "Adding rsyslogd configs..."
sudo cp /tmp/conf/cloudwatch-agent/rsyslog.d/* /etc/rsyslog.d/
