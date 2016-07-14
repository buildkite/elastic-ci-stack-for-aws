#!/bin/bash
set -eu

stack_name=$(buildkite-agent meta-data get stack_name)

echo "--- Deleting stack $stack_name"
aws cloudformation delete-stack --stack-name "$stack_name"