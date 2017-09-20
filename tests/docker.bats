#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Creating files in a docker container are owned by buildkite-agent" {
  run docker run -v "$PWD:/pwd" --rm -it alpine:latest mkdir /pwd/llamas
 	[ $status = 0 ]
  stat llamas
  stat llamas | grep 'Uid: (  501/buildkite-agent)   Gid: (  501/  docker)'
}
