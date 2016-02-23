#!/bin/bash
set -eu
set -x

stack_name=$(buildkite-agent meta-data get stack_name)
bk_pipeline_slug=$(buildkite-agent meta-data get bk_pipeline_slug)

echo "--- Deleting stack $stack_name"
aws cloudformation delete-stack --stack-name "$stack_name"

echo "--- Deleting pipeline $bk_pipeline_slug"
curl --show-error --silent -f -X DELETE "https://api.buildkite.com/v2/organizations/$BUILDKITE_AWS_STACK_ORG_SLUG/pipelines/$bk_pipeline_slug"