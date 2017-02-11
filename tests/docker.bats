#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Check docker reports a version" {
	run docker --version
	[ $status = 0 ]
}
