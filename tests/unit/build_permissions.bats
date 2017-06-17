#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export CHOWN_STUB_DEBUG=/dev/tty

setup() {
  export TEST_TEMP_DIR="${BATS_TMPDIR}/buildperms.$$"
  export BUILDKITE_BUILD_PATH="${TEST_TEMP_DIR}/builds"
  export BUILDKITE_AGENT_STUB="my-agent-1"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline-blah"
  export BUILDKITE_BUILD_CHECKOUT_PATH="${BUILDKITE_BUILD_PATH}/${BUILDKITE_AGENT_STUB}/${BUILDKITE_PIPELINE_SLUG}"
  mkdir -p "$BUILDKITE_BUILD_CHECKOUT_PATH"
}

teardown() {
  [[ -d $BUILDKITE_BUILD_CHECKOUT_PATH ]] && rm -rf "$BUILDKITE_BUILD_CHECKOUT_PATH"
}

@test "Fixing permissions for checkout directories" {
  stub chown "-R buildkite-agent:buildkite-agent ${BUILDKITE_BUILD_PATH}/${BUILDKITE_AGENT_STUB} : echo chowned directory"

  run bash -c "$PWD/packer/conf/buildkite-agent/scripts/fix-buildkite-agent-builds-permissions chown"

  assert_success
  assert_output --partial "chowned directory"
  unstub chown
}

# Previously there were these tests, but I'm not sure that we need them as I can't figure out how
# you would change these variables
#
# ./fix-buildkite-agent-builds-permissions "/"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "one/"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "/two"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "one/two"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "one/two/three"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "/two/"
# => exit 1
#
# ./fix-buildkite-agent-builds-permissions "."
# => exit 2
#
# ./fix-buildkite-agent-builds-permissions ".."
# => exit 2
#
# ./fix-buildkite-agent-builds-permissions ""
# => exit 3