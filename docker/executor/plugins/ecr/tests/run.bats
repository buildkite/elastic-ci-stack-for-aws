#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# export AWS_STUB_DEBUG=/dev/tty

@test "Login to ECR" {
  export BUILDKITE_PLUGIN_ECR_LOGIN=true
  export BUILDKITE_PLUGIN_ECR_NO_INCLUDE_EMAIL=true

  stub aws \
    "ecr get-login --no-include-email : echo docker login -u AWS -p 1234 https://1234.dkr.ecr.us-east-1.amazonaws.com"

  stub docker \
    "login -u AWS -p 1234 https://1234.dkr.ecr.us-east-1.amazonaws.com : echo logging in to docker"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker"

  unstub aws
  unstub docker
}

@test "Login to ECR (without --no-include-email)" {
  export BUILDKITE_PLUGIN_ECR_LOGIN=true
  export BUILDKITE_PLUGIN_ECR_NO_INCLUDE_EMAIL=false

  stub aws \
    "ecr get-login : echo docker login -u AWS -p 1234 https://1234.dkr.ecr.us-east-1.amazonaws.com"

  stub docker \
    "login -u AWS -p 1234 https://1234.dkr.ecr.us-east-1.amazonaws.com : echo logging in to docker"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker"

  unstub aws
  unstub docker
}

@test "Login to ECR with Account IDS" {
  export BUILDKITE_PLUGIN_ECR_LOGIN=true
  export BUILDKITE_PLUGIN_ECR_ACCOUNT_IDS_0=1111
  export BUILDKITE_PLUGIN_ECR_ACCOUNT_IDS_1=2222
  export BUILDKITE_PLUGIN_ECR_NO_INCLUDE_EMAIL=true

  stub aws \
    "ecr get-login --no-include-email --registry-ids 1111 2222 : echo echo logging in to docker"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker"

  unstub aws
}

@test "Login to ECR with Comma-delimited Account IDS (older aws-cli)" {
  export BUILDKITE_PLUGIN_ECR_LOGIN=true
  export BUILDKITE_PLUGIN_ECR_ACCOUNT_IDS="1111,2222,3333"

  stub aws \
    "--version : echo aws-cli/1.11.40 Python/2.7.10 Darwin/16.6.0 botocore/1.5.80" \
    "ecr get-login --registry-ids 1111 2222 3333 : echo echo logging in to docker"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker"

  unstub aws
}

@test "Login to ECR with Comma-delimited Account IDS (newer aws-cli)" {
  export BUILDKITE_PLUGIN_ECR_LOGIN=true
  export BUILDKITE_PLUGIN_ECR_ACCOUNT_IDS="1111,2222,3333"

  stub aws \
    "--version : echo aws-cli/1.11.117 Python/2.7.10 Darwin/16.6.0 botocore/1.5.80" \
    "ecr get-login --no-include-email --registry-ids 1111 2222 3333 : echo echo logging in to docker"

  run $PWD/hooks/pre-command

  assert_success
  assert_output --partial "logging in to docker"

  unstub aws
}
