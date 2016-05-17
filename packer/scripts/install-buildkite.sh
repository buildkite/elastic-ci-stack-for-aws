#!/bin/bash -eu

# Install all 3 versions of the agent

sudo curl -Lf -o /usr/bin/buildkite-agent-stable \
  https://download.buildkite.com/agent/stable/latest/buildkite-agent-`uname -s`-`uname -m`
sudo chmod +x /usr/bin/buildkite-agent-stable

sudo curl -Lf -o /usr/bin/buildkite-agent-unstable \
  https://download.buildkite.com/agent/unstable/latest/buildkite-agent-`uname -s`-`uname -m`
sudo chmod +x /usr/bin/buildkite-agent-unstable

sudo curl -Lf -o /usr/bin/buildkite-agent-experimental \
  https://download.buildkite.com/agent/experimental/latest/buildkite-agent-`uname -s`-`uname -m`
sudo chmod +x /usr/bin/buildkite-agent-experimental

sudo useradd buildkite-agent
sudo usermod -a -G docker buildkite-agent

sudo mkdir -p /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

# This can be removed when stable refers to 3.0
sudo wget -nv https://raw.githubusercontent.com/buildkite/agent/2-1-stable/templates/bootstrap.sh -O /etc/buildkite-agent/2-1-stable-bootstrap.sh
sudo chmod +x /etc/buildkite-agent/2-1-stable-bootstrap.sh

sudo mkdir -p /var/lib/buildkite-agent/builds
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/builds

sudo mkdir -p /var/lib/buildkite-agent/plugins
sudo chown -R buildkite-agent: /var/lib/buildkite-agent/plugins

# Allow buildkite to fix checkout permissions
sudo cp /tmp/conf/buildkite-sudoers.conf /etc/sudoers.d/buildkite
sudo chmod 440 /etc/sudoers.d/buildkite
sudo mv /tmp/conf/scripts/fix-checkout-permissions /usr/bin/

# move custom hooks into place
chmod +x /tmp/conf/hooks/*
sudo cp -a /tmp/conf/hooks/* /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks
