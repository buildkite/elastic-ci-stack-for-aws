#!/usr/bin/env bats

@test "Check docker is running" {
	run docker info
	[ $status = 0 ]
}

@test "Check docker is version 1.12.6" {
	run docker --version
	[ $status = 0 ]
	[ "$output" = "Docker version 1.12.6, build 78d1802" ]
}
