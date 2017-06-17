#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export SSH_ADD_STUB_DEBUG=/dev/tty
export SSH_AGENT_STUB_DEBUG=/dev/tty
# export GIT_STUB_DEBUG=/dev/tty

setup() {
  export TEST_TEMP_DIR="${BATS_TMPDIR}/envhooks.$$"
  export AWS_STACK_CFN_ENV_FILE="$TEST_TEMP_DIR/cfn-env"

  export BUILDKITE_PIPELINE_SLUG="my-pipeline-blah"
  export BUILDKITE_AGENT_NAME="my-agent-1"
  export BUILDKITE_BUILD_CHECKOUT_PATH="/var/lib/buildkite-agent/builds/my-agent-1/my-pipeline-blah"
  export BUILDKITE_BUILD_PATH="/var/lib/buildkite-agent/builds"

  mkdir -p "$TEST_TEMP_DIR"
  echo "TEST_VAR=blah" > "$AWS_STACK_CFN_ENV_FILE"
}

teardown() {
  [[ -d $TEST_TEMP_DIR ]] && rm -rf "$TEST_TEMP_DIR"
}

@test "Environment hook runs without BUILDKITE_SECRETS_BUCKET set" {
  run bash -c "$PWD/packer/conf/buildkite-agent/hooks/environment"

  assert_success
}

@test "Environment hook runs with BUILDKITE_SECRETS_BUCKET set and SECRETS_PLUGIN_ENABLED disabled" {
  export BUILDKITE_SECRETS_BUCKET=my-llama-secrets
  export SECRETS_PLUGIN_ENABLED=false

  run bash -c "$PWD/packer/conf/buildkite-agent/hooks/environment"

  assert_success
}