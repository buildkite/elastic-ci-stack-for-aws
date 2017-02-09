#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Check docker is version 1.13.1" {
	run sh -c  "docker --version | grep 'Docker version 1.13.1,'"
	[ $status = 0 ]
}
