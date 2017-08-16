#!/usr/bin/env bats

@test "Check low disk docker cron script can run" {
	run /etc/cron.daily/docker-low-disk-gc
	[ $status = 0 ]
}

@test "Check docker cron script can run" {
	run /etc/cron.daily/docker-gc
	[ $status = 0 ]
}