#!/usr/bin/env bats

FIX_PERMISSIONS_SCRIPT="/src/packer/linux/conf/buildkite-agent/scripts/fix-buildkite-agent-builds-permissions"

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "/" "abc" "abc"
	[ "$status" -eq 1 ]
}

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc/" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "/abc" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc/def" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc/def/ghi" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the agent arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "/abc/" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "/" "abc"
	[ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc/" "abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "/abc" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc/def" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc/def/ghi" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the org arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "/abc/" "abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "/"
	[ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "abc/"
  [ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "/abc"
  [ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "abc/def"
  [ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "abc/def/ghi"
  [ "$status" -eq 1 ]
}

@test "Slashes in the pipeline arg cause an exit 1" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "/abc/"
  [ "$status" -eq 1 ]
}

@test "Single dot traversal in the agent arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" "." "abc" "abc"
  [ "$status" -eq 2 ]
}

@test "Double dot traversal in the agent arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" ".." "abc" "abc"
  [ "$status" -eq 2 ]
}

@test "Single dot traversal in the org arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "." "abc"
  [ "$status" -eq 2 ]
}

@test "Double dot traversal in the org arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" ".." "abc"
  [ "$status" -eq 2 ]
}

@test "Single dot traversal in the pipeline arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" "."
  [ "$status" -eq 2 ]
}

@test "Double dot traversal in the pipeline arg cause an exit 2" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" ".."
  [ "$status" -eq 2 ]
}

@test "Blank agent arg cause an exit 3" {
  run "$FIX_PERMISSIONS_SCRIPT" "" "abc" "abc"
  [ "$status" -eq 3 ]
}

@test "Blank org arg cause an exit 3" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "" "abc"
  [ "$status" -eq 3 ]
}

@test "Blank pipeline arg cause an exit 3" {
  run "$FIX_PERMISSIONS_SCRIPT" "abc" "abc" ""
  [ "$status" -eq 3 ]
}
