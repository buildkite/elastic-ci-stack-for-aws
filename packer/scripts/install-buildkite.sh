#!/bin/bash -eu

sudo sh -c 'echo deb https://apt.buildkite.com/buildkite-agent unstable main > /etc/apt/sources.list.d/buildkite-agent.list'
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 32A37959C2FA5C3C99EFBC32A79206696452D198
sudo apt-get update -yq
sudo apt-get install -y buildkite-agent

# move custom hooks into place
chmod +x /tmp/conf/hooks/*
cp -a /tmp/conf/hooks/* /var/lib/buildkite/hooks

# install ssh-agent systemd config
cp -a /tmp/conf/ssh-agent.conf /etc/systemd/system/