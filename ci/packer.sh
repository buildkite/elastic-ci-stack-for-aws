#!/bin/bash -eu

set -o pipefail

cd $(dirname $0)/../packer/

packer validate buildkite-ami.json
packer build buildkite-ami.json | tee packer.output
buildkite-agent artifact upload packer.output