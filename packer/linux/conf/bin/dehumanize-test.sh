#!/bin/bash
set -o pipefail

. "$(dirname "$0")"/dehumanize.sh

test_without_unit(){
  assertEquals 45 $(dehumanize 45)
}

test_bytes(){
  assertEquals 45 $(dehumanize 45b)
  assertEquals 45 $(dehumanize 45B)
}

test_kilobytes(){
  assertEquals 46080 $(dehumanize 45kb)
  assertEquals 46080 $(dehumanize 45KB)
}

test_megabytes(){
  assertEquals 47185920 $(dehumanize 45mb)
  assertEquals 47185920 $(dehumanize 45MB)
}

test_gigabytes(){
  assertEquals 48318382080 $(dehumanize 45gb)
  assertEquals 48318382080 $(dehumanize 45GB)
}

test_terabytes(){
  assertEquals 49478023249920 $(dehumanize 45tb)
  assertEquals 49478023249920 $(dehumanize 45TB)
}

test_using_decimals(){
  assertEquals 1610612736 $(dehumanize 1.5gb)
}

. shunit2
