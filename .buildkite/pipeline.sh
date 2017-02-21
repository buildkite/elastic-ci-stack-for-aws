#!/bin/bash

export stack_name="buildkite-aws-stack-test-$$"
export queue_name="testqueue-$$"

cat << EOF
steps:
  - command: .buildkite/steps/lint.sh
    name: "Run linting on shell scripts"
    agents:
      queue: aws-stack

  - wait

  - command: .buildkite/steps/packer.sh
    name: "Build packer image"
    agents:
      queue: aws-stack

  - wait

  - command: .buildkite/steps/test.sh
    name: "Launch :cloudformation: stack"
    agents:
      queue: aws-stack
    artifact_paths: "build/*.json"

  - wait

  - command: "sleep 2"
    name: "Run sleep 2 on :buildkite: agent"
    timeout_in_minutes: 5
    env:
      BUILDKITE_SECRETS_KEY: $BUILDKITE_SECRETS_KEY
    agents:
      stack: $stack_name
      queue: $queue_name

  - wait

  - command: .buildkite/steps/publish.sh
    name: "Publishing :cloudformation: stack"
    agents:
      queue: aws-stack
    artifact_paths: "templates/mappings.yml;build/aws-stack.json"
    concurrency_group: "aws-stack-publish"
    concurrency: 1

  - wait

  - command: .buildkite/steps/cleanup.sh
    name: "Cleanup"
    agents:
      queue: aws-stack
EOF

buildkite-agent meta-data set stack_name "$stack_name"
buildkite-agent meta-data set queue_name "$queue_name"

