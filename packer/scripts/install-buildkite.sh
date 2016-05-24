#!/bin/bash -eu

# Install all 3 versions of the agent

echo "Downloading buildkite-agent stable..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-stable \
  "https://download.buildkite.com/agent/stable/latest/buildkite-agent-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/bin/buildkite-agent-stable
buildkite-agent-stable --version

echo "Downloading buildkite-agent unstable..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-unstable \
  "https://download.buildkite.com/agent/unstable/latest/buildkite-agent-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/bin/buildkite-agent-unstable
buildkite-agent-unstable --version

echo "Downloading buildkite-agent experimental..."
sudo curl -Lsf -o /usr/bin/buildkite-agent-experimental \
  "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-$(uname -s)-$(uname -m)"
sudo chmod +x /usr/bin/buildkite-agent-experimental
buildkite-agent-experimental --version

echo "Creating buildkite-agent user..."
sudo useradd buildkite-agent
sudo usermod -a -G docker buildkite-agent

echo "Downloading legacy bootstrap.sh for v2 stable agent..."
sudo mkdir -p /etc/buildkite-agent
sudo curl -Lsf -o /etc/buildkite-agent/bootstrap.sh \
  https://raw.githubusercontent.com/buildkite/agent/2-1-stable/templates/bootstrap.sh
sudo chmod +x /etc/buildkite-agent/bootstrap.sh
sudo chown -R buildkite-agent: /etc/buildkite-agent/bootstrap.sh

echo "Creating hooks dir..."
sudo mkdir -p /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Copying custom hooks..."
sudo cp -a /tmp/conf/hooks/* /etc/buildkite-agent/hooks
sudo chmod +x /etc/buildkite-agent/hooks/*
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Configuring sudoers so the environment hook can fix incorrectly owned files..."
sudo cp /tmp/conf/buildkite-sudoers.conf /etc/sudoers.d/buildkite
sudo chmod 440 /etc/sudoers.d/buildkite
sudo mv /tmp/conf/scripts/fix-checkout-permissions /usr/bin/

echo "Creating builds dir..."
sudo mkdir -p /var/lib/buildkite-agent/builds
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/builds

echo "Creating plugins dir..."
sudo mkdir -p /var/lib/buildkite-agent/plugins
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/plugins
