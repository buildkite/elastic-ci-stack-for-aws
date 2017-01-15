#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Check docker is version 1.12.6" {
	run sh -c  "docker --version | grep 'Docker version 1.12.6,'"
	[ $status = 0 ]
}
