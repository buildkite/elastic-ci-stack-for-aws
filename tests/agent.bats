#!/usr/bin/env bats

@test "Check buildkite-agent is running" {
	ps ax >&2
	run pgrep -a buildkite-agent
	[ $status = 0 ]
}