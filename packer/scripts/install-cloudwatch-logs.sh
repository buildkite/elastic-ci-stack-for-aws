#!/bin/bash -eu

sudo yum install -y awslogs

mkdir -p /var/awslogs/state

cat << EOF | sudo tee /etc/awslogs/awslogs.conf
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = /var/log/messages
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S

[/var/log/buildkite-agent.log]
file = /var/log/buildkite-agent.log
log_group_name = /var/log/buildkite-agent.log
log_stream_name = {instance_id}
datetime_format = %Y-%m-%d %H:%M:%S
EOF

sudo chkconfig awslogs on