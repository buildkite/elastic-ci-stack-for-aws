#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export DOCKER_STUB_DEBUG=/dev/tty

@test "Login to single registry" {
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_USERNAME="blah"
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_PASSWORD="llamas"

  stub docker \
    "login --username blah --password llamas : echo logging in to docker hub"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker hub"

  unstub docker
}

@test "Login to multiple registries" {
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_0_USERNAME="blah"
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_0_SERVER="my.registry.blah"
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_0_PASSWORD="llamas"
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_1_USERNAME="blah"
  export BUILDKITE_PLUGIN_DOCKER_LOGIN_1_PASSWORD="llamas"

  stub docker \
    "login --username blah --password llamas my.registry.blah : echo logging in to my.registry.blah" \
    "login --username blah --password llamas : echo logging in to docker hub"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to my.registry.blah"
  assert_output --partial "logging in to docker hub"

  unstub docker
}