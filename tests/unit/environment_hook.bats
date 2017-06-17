#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export AWS_STUB_DEBUG=/dev/tty
# export SSH_ADD_STUB_DEBUG=/dev/tty
# export SSH_AGENT_STUB_DEBUG=/dev/tty
# export GIT_STUB_DEBUG=/dev/tty

setup() {
  export TEST_TEMP_DIR="${BATS_TMPDIR}/envhooks.$$"
  export AWS_STACK_CFN_ENV_FILE="$TEST_TEMP_DIR/cfn-env"

  export BUILDKITE_AGENT_NAME="llamas-1"
  export BUILDKITE_BUILD_CHECKOUT_PATH="/var/lib/buildkite-agent/builds/my-agent-1/my-pipeline-blah"
  export BUILDKITE_BUILD_PATH="/var/lib/buildkite-agent/builds"

  mkdir -p "$TEST_TEMP_DIR"
  echo "TEST_VAR=blah" > "$AWS_STACK_CFN_ENV_FILE"

  stub ssh-agent "-s : echo export SSH_AGENT_PID=224;"
  stub timeout "30 docker ps : echo waiting for docker to start"
  stub sudo "/usr/bin/fix-buildkite-agent-builds-permissions : echo fixing agent build permissions"
}

teardown() {
  [[ -d $TEST_TEMP_DIR ]] && rm -rf "$TEST_TEMP_DIR"

  assert_output --partial "waiting for docker to start"
  assert_output --partial "fixing agent build permissions"

  unstub timeout
  unstub ssh-agent
  unstub sudo
}

@test "Environment hook runs without BUILDKITE_SECRETS_BUCKET set" {
  run bash -c "$PWD/packer/conf/buildkite-agent/hooks/environment"

  assert_success
  assert_output --partial "llamas"
}