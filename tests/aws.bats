#!/usr/bin/env bats

@test "Check awslogs is running" {
	run sudo service "awslogs" status
	[ $status = 0 ]
}