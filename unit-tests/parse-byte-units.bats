#!/usr/bin/env bats

PARSE_BYTE_UNITS_SCRIPT="/src/packer/linux/conf/bin/bk-parse-byte-units.sh"

@test "parse with invalid input" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "llamas"
  [ "$status" -eq 1 ]
}

@test "parse with no input" {
  run "$PARSE_BYTE_UNITS_SCRIPT"
  [ "$status" -eq 1 ]
}

@test "parse without unit" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45"
  [ "$status" -eq 0 ]
  [ "$output" = "45" ]
}

@test "parse with bytes" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45b"
  [ "$status" -eq 0 ]
  [ "$output" = "45" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45B"
  [ "$status" -eq 0 ]
  [ "$output" = "45" ]
}

@test "parse with kilobytes" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45kb"
  [ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45KB"
  [ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45Kb"
  [ "$status" -eq 0 ]
  [ "$output" = "46080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45K"
  [ "$status" -eq 0 ]
  [ "$output" = "46080" ]
}

@test "parse with megabytes" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45mb"
  [ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45MB"
  [ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45Mb"
  [ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45M"
  [ "$status" -eq 0 ]
  [ "$output" = "47185920" ]
}

@test "parse with gigabytes" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45gb"
  [ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45GB"
  [ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45Gb"
  [ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45G"
  [ "$status" -eq 0 ]
  [ "$output" = "48318382080" ]
}

@test "parse with terabytes" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "45tb"
  [ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45TB"
  [ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45Tb"
  [ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45T"
  [ "$status" -eq 0 ]
  [ "$output" = "49478023249920" ]
}

@test "parse with decimals" {
  run "$PARSE_BYTE_UNITS_SCRIPT" "1.5gb"
  [ "$status" -eq 0 ]
  [ "$output" = "1610612736" ]
  run "$PARSE_BYTE_UNITS_SCRIPT" "45TB"
}
