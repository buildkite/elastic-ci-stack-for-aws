#!/bin/bash

export stack_name="buildkite-aws-stack-test-$$"
export queue_name="testqueue-$$"

cat << EOF
steps:
  - name: "Run linting on shell scripts"
    command: .buildkite/steps/lint.sh
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"

  - wait

  - command: .buildkite/steps/packer.sh
    name: "Build packer image"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"

  - wait

  - command: .buildkite/steps/test.sh
    name: "Launch :cloudformation: stack"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"
    artifact_paths:
      - "build/*.json"
      - "build/*.yml"

  - wait

  - command: "/usr/local/bin/bats --pretty tests"
    name: "Run tests on :buildkite: agent"
    timeout_in_minutes: 5
    env:
      BUILDKITE_SECRETS_KEY: $BUILDKITE_SECRETS_KEY
    agents:
      stack: $stack_name
      queue: $queue_name

  - wait

  - command: .buildkite/steps/publish.sh
    name: "Publishing branch and commit versions of :cloudformation: stack"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"
    artifact_paths: "templates/mappings.yml;build/aws-stack.json;build/aws-stack.yml"
    concurrency_group: "aws-stack-publish"
    concurrency: 1

  - wait

  - command: .buildkite/steps/publish_tagged.sh
    name: "Publishing :cloudformation: stack"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"
    concurrency_group: "aws-stack-publish"
    concurrency: 1

  - wait

  - command: .buildkite/steps/cleanup.sh
    name: "Cleanup"
    agents:
      queue: "${BUILDKITE_AGENT_META_DATA_QUEUE}"

EOF

buildkite-agent meta-data set stack_name "$stack_name"
buildkite-agent meta-data set queue_name "$queue_name"