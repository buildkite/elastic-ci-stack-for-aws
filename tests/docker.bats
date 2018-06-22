#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Creating files in a docker container are owned by buildkite-agent" {
  run docker run -v "$PWD:/pwd" --rm -it alpine:latest mkdir /pwd/llamas
 	[ $status = 0 ]
  stat llamas
  stat llamas | grep 'Uid: ( 2000/buildkite-agent)   Gid: ( 1001/  docker)'
}

@test "Containers can access docker socket" {
  run docker run --rm -v /var/run/docker.sock:/var/run/docker.sock docker:latest version
 	[ $status = 0 ]
}
