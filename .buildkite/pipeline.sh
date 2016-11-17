#!/bin/bash

export stack_name="buildkite-aws-stack-test-$$"
export queue_name="testqueue-$$"

cat << EOF
steps:
  - command: .buildkite/steps/packer.sh
    name: ":packer:"
    agents:
      queue: aws-stack

  - wait

  - command: .buildkite/steps/test.sh
    name: ":cloudformation:"
    agents:
      queue: aws-stack
    artifact_paths: "build/*.json"

  - wait

  - command: sleep 5
    name: ":buildkite:"
    timeout_in_minutes: 5
    env:
      BUILDKITE_SECRETS_KEY: $BUILDKITE_SECRETS_KEY
    agents:
      stack: $stack_name
      queue: $queue_name

  - wait

  - command: .buildkite/steps/publish.sh
    name: ":rocket: :cloudformation:"
    agents:
      queue: aws-stack
    artifact_paths: "templates/mappings.yml;build/aws-stack.json"

  - wait

  - command: .buildkite/steps/cleanup.sh
    name: ":closed_book:"
    agents:
      queue: aws-stack
EOF

buildkite-agent meta-data set stack_name "$stack_name"
buildkite-agent meta-data set queue_name "$queue_name"

