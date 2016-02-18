#!/bin/bash -eu

set -o pipefail

cd $(dirname $0)/../packer/

packer_hash=$(find . -type f -print0 | xargs -0 sha1sum | cut -b-40 | sort | sha1sum | awk '{print $1}')
packer_file="packer-${packer_hash}.output"

echo "Packer image hash is $packer_hash"

buildkite-agent artifact download "$packer_file" .

if [[ ! -f $packer_file ]] ; then
  packer validate buildkite-ami.json
  packer build buildkite-ami.json | tee "$packer_file"
  buildkite-agent artifact upload "$packer_file"
fi