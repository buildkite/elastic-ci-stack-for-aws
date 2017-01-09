#!/usr/bin/env bats

@test "Check awslogs is running" {
	run service "awslogs" status
	[ $status = 0 ]
}