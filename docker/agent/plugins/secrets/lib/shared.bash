#!/bin/bash

s3_exists() {
  local bucket="$1"
  local key="$2"
  local aws_s3_args=("--region=$AWS_DEFAULT_REGION")

  if ! aws s3api head-object "${aws_s3_args[@]}" --bucket "$bucket" --key "$key" &>/dev/null ; then
    return 1
  fi
}

s3_bucket_exists() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>&1 | grep -q "Not Found" ; then
    return 1
  fi
}

s3_download() {
  local bucket="$1"
  local key="$2"
  local aws_s3_args=("--quiet" "--region=$AWS_DEFAULT_REGION")

  if [[ "${BUILDKITE_USE_KMS:-true}" =~ ^(true|1)$ ]] ; then
    aws_s3_args+=("--sse" "aws:kms")
  fi

  if ! aws s3 cp "${aws_s3_args[@]}" "s3://$1/$2" /dev/stdout ; then
    exit 1
  fi
}

add_ssh_private_key_to_agent() {
  local ssh_key="$1"

  if [[ -z "${SSH_AGENT_PID:-}" ]] ; then
    echo "Starting an ephemeral ssh-agent" >&2;
    eval "$(ssh-agent -s)"
  fi

  echo "Loading ssh-key into ssh-agent (pid ${SSH_AGENT_PID:-})" >&2;
  echo "$ssh_key" | env SSH_ASKPASS="/bin/false" ssh-add -
}

grep_secrets() {
  grep -E 'private_ssh_key|id_rsa_github|env|environment|git-credentials$' "$@"
}
