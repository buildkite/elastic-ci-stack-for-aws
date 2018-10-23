#!/usr/bin/env bats

@test "Creating files in a docker container are owned by buildkite-agent" {
  run docker run -v "$PWD:/pwd" --rm -it alpine:latest mkdir /pwd/llamas
 	[ $status = 0 ]
  stat llamas
  stat llamas | grep 'Uid: ( 2000/buildkite-agent)   Gid: ( 1001/  docker)'
}

