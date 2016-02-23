#!/bin/bash

export stack_name="buildkite-aws-stack-test-$$"
export queue_name="testqueue-$$"

cat << EOF
steps:
  - command: ci/packer.sh
    name: "Build packer image"
    agents:
      queue: aws-stack

  - wait

  - command: ci/test.sh
    name: "Test :cloudformation: stack"
    agents:
      queue: aws-stack

  - wait

  - command: sleep 5
    name: "Running a command on :buildkite: agent"
    timeout_in_minutes: 5
    agents:
      stack: $stack_name
      queue: $queue_name

  - wait

  - command: ci/publish.sh
    name: "Publishing :cloudformation: stack"
    branches: master
    agents:
      queue: aws-stack

  - wait

  - command: ci/cleanup.sh
    name: "Cleanup"
    agents:
      queue: aws-stack
EOF

buildkite-agent meta-data set stack_name "$stack_name"
buildkite-agent meta-data set queue_name "$queue_name"

