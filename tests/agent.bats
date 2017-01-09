#!/usr/bin/env bats

@test "Check buildkite-agent-1 is running" {
	run service "buildkite-agent-1" status
	[ $status = 0 ]
}

@test "Check terminationd is running" {
	run service "terminationd" status
	[ $status = 0 ]
}