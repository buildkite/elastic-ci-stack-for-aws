#!/bin/bash -eu

set -o pipefail

cd $(dirname $0)/../packer/

packer validate buildkite-ubuntu-15.04.json
packer build buildkite-ubuntu-15.04.json | tee packer.output
buildkite-agent artifact upload packer.output