#!/usr/bin/env bats

@test "Check awslogs has a pid file" {
	test -f /var/run/awslogs.pid
	[ $status = 0 ]
}

@test "Check awslogs is running" {
	run ps -p "$(cat /var/run/awslogs.pid)"
	[ $status = 0 ]
}