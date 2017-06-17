#!/bin/bash

is_latest_tag() {
   [[ "$BUILDKITE_TAG" = $(git describe --abbrev=0 --tags --match 'v*') ]]
}

if is_latest_tag ; then
  buildkite-agent artifact download templates/mappings.yml templates/
  buildkite-agent artifact download "build/**" build/

  echo "--- Publishing stack to https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.yml"
  aws s3 cp --acl public-read templates/mappings.yml "s3://buildkite-aws-stack/mappings.yml"
  aws s3 cp --acl public-read build/aws-stack.json "s3://buildkite-aws-stack/aws-stack.json"
  aws s3 cp --acl public-read build/aws-stack.yml "s3://buildkite-aws-stack/aws-stack.yml"
else
  echo "Skipping publishing latest, '$BUILDKITE_TAG' doesn't match '$(git describe origin/master --tags --match='v*')'"
fi