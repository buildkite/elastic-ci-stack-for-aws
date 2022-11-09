#!/bin/bash
set -eu -o pipefail
echo "Installing nix"
sh <(curl -L https://nixos.org/nix/install) --daemon
