#!/bin/bash
set -euo pipefail

# Prints the GitHub release body for a tag: its CHANGELOG.md entry followed by
# upgrade instructions for its release line. Run it after editing the entry.

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <RELEASE_TAG>" >&2
  echo "Example: $0 v7.11.1 >release-notes.md" >&2
  exit 1
fi

tag=$1
entry=$(awk -v heading="## [${tag}](" '
  index($0, heading) == 1 { found = 1; print; next }
  found && /^## \[/ { exit }
  found { print }' CHANGELOG.md)
if [[ -z $entry ]]; then
  echo "CHANGELOG.md has no entry for ${tag}" >&2
  exit 1
fi

template="https://s3.amazonaws.com/buildkite-aws-stack/${tag}/aws-stack.yml"

printf '%s\n\n## Upgrading\n\n' "$entry"
case $tag in
v7.*)
  # shellcheck disable=SC2016 # Backticks are Markdown code spans.
  printf '%s\n\n' \
    'Upgrading from v6? Follow the [v7 upgrade guide](https://buildkite.com/docs/agent/self-hosted/aws/elastic-ci-stack/ec2-linux-and-windows/v6-v7-upgrade-guide), remove retired parameters, and rebuild custom AMIs from the v7 base.' \
    'For Windows, update the template and AMI together. Custom `InstanceRoleARN` roles also need `autoscaling:CompleteLifecycleAction` for the stack'"'"'s Auto Scaling group.'
  printf 'Update your CloudFormation stack with:<br>\n%s\n\n' "$template"
  printf 'Launch new stacks in a dedicated CI AWS account:\n\n'
  ;;
v6.*)
  printf 'Perform a CloudFormation stack update with the following URL:<br>\n%s\n\n' "$template"
  printf 'If you want to launch a new stack, you can use this link (make sure not to use your production AWS account, create a new one for CI):\n\n'
  ;;
*)
  echo "Unsupported release line: ${tag}" >&2
  exit 1
  ;;
esac
printf '[![Launch Buildkite AWS Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=%s)\n' "$template"
