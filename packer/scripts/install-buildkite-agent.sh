#!/bin/bash

set -eu -o pipefail

echo "Installing dependencies..."
sudo yum update -y -q
sudo yum install -y -q git-core

echo "Creating buildkite-agent user..."
sudo useradd --base-dir /var/lib buildkite-agent
sudo usermod -a -G docker buildkite-agent

echo "Adding docker-compose.yml for buildkite..."
sudo cp /tmp/conf/buildkite-agent/docker-compose.yml /var/lib/buildkite-agent/
sudo chown buildkite-agent: /var/lib/buildkite-agent/docker-compose.yml
sudo cp /tmp/conf/buildkite-agent/entrypoint.sh /var/lib/buildkite-agent/
sudo chown buildkite-agent: /var/lib/buildkite-agent/entrypoint.sh
sudo touch /var/lib/buildkite-agent/.env
sudo chown buildkite-agent: /var/lib/buildkite-agent/.env

echo "Creating hooks dir..."
sudo mkdir -p /etc/buildkite-agent/hooks
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Copying custom hooks..."
sudo cp -a /tmp/conf/buildkite-agent/hooks/* /etc/buildkite-agent/hooks
sudo chmod +x /etc/buildkite-agent/hooks/*
sudo chown -R buildkite-agent: /etc/buildkite-agent/hooks

echo "Adding termationd hook..."
sudo cp /tmp/conf/buildkite-agent/terminationd/hook /etc/terminationd/hook