#!/usr/bin/env bats

@test "Check buildkite-agent is running" {
	run pgrep -a buildkite-agent
	[ $status = 0 ]
}