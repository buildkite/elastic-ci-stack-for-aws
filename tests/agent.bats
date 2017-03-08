#!/usr/bin/env bats

@test "Check buildkite-agent-1 is running" {
	run service "buildkite-agent-1" status
	[ $status = 0 ]
}
