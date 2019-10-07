#!/usr/bin/env bats

DEHUMANIZE_SCRIPT="/src/packer/linux/conf/bin/dehumanize.sh"

@test "dehumanize with invalid input" {
  run "$DEHUMANIZE_SCRIPT" "llamas"
	[ "$status" -eq 1 ]
}

@test "dehumanize with no input" {
  run "$DEHUMANIZE_SCRIPT"
	[ "$status" -eq 1 ]
}

@test "dehumanize without unit" {
  run "$DEHUMANIZE_SCRIPT" "45"
	[ "$status" -eq 0 ]
  [ "$output" = "45" ]
}

@test "dehumanize with bytes" {
  run "$DEHUMANIZE_SCRIPT" "45b"
	[ "$status" -eq 0 ]
  [ "$output" = "45" ]
  run "$DEHUMANIZE_SCRIPT" "45B"
	[ "$status" -eq 0 ]
  [ "$output" = "45" ]
}

@test "dehumanize with kilobytes" {
  run "$DEHUMANIZE_SCRIPT" "45kb"
	[ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$DEHUMANIZE_SCRIPT" "45KB"
	[ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$DEHUMANIZE_SCRIPT" "45Kb"
	[ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$DEHUMANIZE_SCRIPT" "45K"
	[ "$status" -eq 0 ]
  [ "$output" = "46080" ]
}

@test "dehumanize with megabytes" {
  run "$DEHUMANIZE_SCRIPT" "45mb"
	[ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$DEHUMANIZE_SCRIPT" "45MB"
	[ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$DEHUMANIZE_SCRIPT" "45Mb"
	[ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$DEHUMANIZE_SCRIPT" "45M"
	[ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
}

@test "dehumanize with gigabytes" {
  run "$DEHUMANIZE_SCRIPT" "45gb"
	[ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$DEHUMANIZE_SCRIPT" "45GB"
	[ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$DEHUMANIZE_SCRIPT" "45Gb"
	[ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$DEHUMANIZE_SCRIPT" "45G"
	[ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
}

@test "dehumanize with terabytes" {
  run "$DEHUMANIZE_SCRIPT" "45tb"
	[ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$DEHUMANIZE_SCRIPT" "45TB"
	[ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$DEHUMANIZE_SCRIPT" "45Tb"
	[ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$DEHUMANIZE_SCRIPT" "45T"
	[ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
}

@test "dehumanize with decimals" {
  run "$DEHUMANIZE_SCRIPT" "1.5gb"
	[ "$status" -eq 0 ]
  [ "$output" = "1610612736" ]
  run "$DEHUMANIZE_SCRIPT" "45TB"
}
