#!/bin/bash -eu

sudo sh -c 'echo deb https://apt.buildkite.com/buildkite-agent unstable main > /etc/apt/sources.list.d/buildkite-agent.list'
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198
sudo apt-get update && sudo apt-get install -y buildkite-agent

sudo mv /tmp/conf/buildkite-agent@.service /lib/systemd/system/buildkite-agent@.service
sudo chown root: /lib/systemd/system/buildkite-agent@.service
sudo systemctl daemon-reload

sudo mv /tmp/conf/buildkite-hooks/* /etc/buildkite-agent/hooks/
sudo mkdir -p /var/lib/buildkite-agent