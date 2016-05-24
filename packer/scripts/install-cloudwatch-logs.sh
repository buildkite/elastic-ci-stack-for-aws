#!/bin/bash -eu

sudo yum install -y awslogs

sudo mkdir -p /var/awslogs/state

cat << EOF | sudo tee /etc/awslogs/awslogs.conf
[general]
state_file = /var/awslogs/state/agent-state

[/var/log/messages]
file = /var/log/messages
log_group_name = /var/log/messages
log_stream_name = {instance_id}
datetime_format = %b %d %H:%M:%S

sudo chkconfig awslogs on
