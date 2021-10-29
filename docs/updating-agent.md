# Updating the Agent

The `buildkite-agent` is built in to the AMIs by the Packer build. The agent 
binary is downloaded from download.buildkite.com.

Once you have [released](https://github.com/buildkite/agent/blob/master/RELEASE.md) an updated
version of the agent, you can incorporate it into the Elastic CI Stack
for AWS template.

See https://github.com/buildkite/elastic-ci-stack-for-aws/pull/935 for an
example of updating the buildkite-agent.

1. Create a new branch
1. Update and commit a change to the Packer install scripts for [Linux](#linux) and [Windows](#windows) for the new version
1. Push your branch and open a pull request
1. Wait for CI to go green
1. Merge

## Linux

Update the `AGENT_VERSION` variable in [`packer/linux/scripts/install-buildkite-agent.sh`](packer/linux/scripts/install-buildkite-agent.sh)
to change which version is installed during the Packer build for the Linux AMI.

## Windows

Update the `AGENT_VERSION` variable in [`packer/windows/scripts/install-buildkite-agent.ps1`](packer/windows/scripts/install-buildkite-agent.ps1)
to change which version is installed during the Packer build for the Windows
AMI.
