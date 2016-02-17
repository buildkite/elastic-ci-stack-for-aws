#!/bin/bash -eu

cd $(dirname $0)/../packer/

packer validate buildkite-ubuntu-15.04.json
packer build -machine-readable buildkite-ubuntu-15.04.json | tee packer.output
buildkite-agent artifact upload packer.output