#!/usr/bin/env bash

set -euxo pipefail

mkdir -p /home/ec2-user/.ssh
curl https://s3-ap-southeast-2.amazonaws.com/oculo-infrastructure-artifacts/authorized_keys > /home/ec2-user/.ssh/authorized_keys
chown ec2-user:ec2-user /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys
