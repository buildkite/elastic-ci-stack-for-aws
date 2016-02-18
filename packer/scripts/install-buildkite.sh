#!/bin/bash -eu

cat << EOF | sudo tee -a  /etc/yum.repos.d/buildkite-agent.repo
[buildkite-agent]
name = Buildkite Pty Ltd
baseurl = https://yum.buildkite.com/buildkite-agent/unstable/x86_64/
enabled=1
gpgcheck=0
priority=1
EOF

sudo yum -y install buildkite-agent
sudo usermod -a -G docker buildkite-agent

# move custom hooks into place
chmod +x /tmp/conf/hooks/*
sudo cp -a /tmp/conf/hooks/* /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

# install ssh-agent service
sudo cp -a /tmp/conf/ssh-agent.conf /etc