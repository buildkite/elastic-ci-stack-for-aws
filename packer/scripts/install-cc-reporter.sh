#!/usr/bin/env bash

set -euxo pipefail

CC_TEST_REPORTER=/usr/bin/cc-test-reporter

sudo curl -Lsf -o "${CC_TEST_REPORTER}" https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64
sudo chmod a+x "${CC_TEST_REPORTER}"
