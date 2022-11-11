#!/bin/bash
set -eu -o pipefail
echo "Installing nix"
sh <(curl -L https://nixos.org/nix/install) --daemon
sudo echo ". /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" >> /var/lib/buildkite-agent/.bash_profile
