#!/bin/bash

set -eu -o pipefail

echo "Installing dependencies..."
sudo yum update -y -q
sudo yum install -y -q git-core

echo "Creating buildkite-agent user..."
sudo useradd --base-dir /var/lib buildkite-agent
sudo usermod -a -G docker buildkite-agent

echo "Downloading buildkite-agent stable..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-stable \
  "https://download.buildkite.com/agent/stable/latest/buildkite-agent-linux-amd64"
sudo chmod +x /usr/bin/buildkite-agent-stable
buildkite-agent-stable --version

echo "Downloading buildkite-agent beta..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-beta \
  "https://download.buildkite.com/agent/unstable/latest/buildkite-agent-linux-amd64"
sudo chmod +x /usr/bin/buildkite-agent-beta
buildkite-agent-beta --version

echo "Downloading buildkite-agent edge..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-edge \
  "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-amd64"
sudo chmod +x /usr/bin/buildkite-agent-edge
buildkite-agent-edge --version

echo "Downloading legacy bootstrap.sh for v2 stable agent..."
sudo mkdir -p /etc/buildkite-agent
sudo curl -Lsf -o /etc/buildkite-agent/bootstrap.sh \
  https://raw.githubusercontent.com/buildkite/agent/2-1-stable/templates/bootstrap.sh
sudo chmod +x /etc/buildkite-agent/bootstrap.sh
sudo chown -R buildkite-agent: /etc/buildkite-agent

echo "Adding scripts..."
sudo cp /tmp/conf/buildkite-agent/scripts/* /usr/bin

echo "Adding sudoers config..."
sudo cp /tmp/conf/buildkite-agent/sudoers.conf /etc/sudoers.d/buildkite-agent
sudo chmod 440 /etc/sudoers.d/buildkite-agent

echo "Creating hooks dir..."
sudo mkdir -p /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Copying custom hooks..."
sudo cp -a /tmp/conf/buildkite-agent/hooks/* /etc/buildkite-agent/hooks
sudo chmod +x /etc/buildkite-agent/hooks/*
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Creating builds dir..."
sudo mkdir -p /var/lib/buildkite-agent/builds
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/builds

echo "Creating plugins dir..."
sudo mkdir -p /var/lib/buildkite-agent/plugins
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/plugins

echo "Adding init.d template..."
sudo cp /tmp/conf/buildkite-agent/init.d/buildkite-agent /etc/buildkite-agent/init.d.tmpl

echo "Adding termationd hook..."
sudo cp /tmp/conf/buildkite-agent/terminationd/hook /etc/terminationd/hook

echo "Copying built-in plugins..."
sudo mkdir -p /usr/local/buildkite-aws-stack/plugins
sudo cp -a /tmp/plugins/* /usr/local/buildkite-aws-stack/plugins/
sudo chown -R buildkite-agent: /usr/local/buildkite-aws-stack