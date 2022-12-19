#!/bin/bash

set -eu -o pipefail


echo "Installing cloudwatch agent..."
sudo yum install -y amazon-cloudwatch-agent

echo "Adding amazon-cloudwatch-agent config..."
sudo cp /tmp/conf/cloudwatch-agent/config.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Configuring amazon-cloudwatch-agent to start at boot"
sudo systemctl enable amazon-cloudwatch-agent

# These will send some systemctl service logs (like the buildkite agent and docker) to logfiles
echo "Adding rsyslogd configs..."
sudo cp /tmp/conf/cloudwatch-agent/rsyslog.d/* /etc/rsyslog.d/
