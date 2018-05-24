#!/usr/bin/env bats

@test "Check buildkite-agent-1 is running" {
	run systemctl is-active --quiet "buildkite-agent@1"
	[ $status = 0 ]
}

@test "Check lifecycled is running" {
	run systemctl is-active --quiet "lifecycled"
	[ $status = 0 ]
}
