#!/bin/bash -eux

cd $(dirname $0)/../packer/
packer build buildkite-ubuntu-15.04.json