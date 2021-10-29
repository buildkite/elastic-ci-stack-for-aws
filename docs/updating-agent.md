# Updating the Agent

## Linux

Packer installs the `buildkite-agent` using the [`packer/linux/scripts/install-buildkite-agent.sh`](packer/linux/scripts/install-buildkite-agent.sh)
script. Update the `AGENT_VERSION` variable in this file to
change which version is installed.

The agent binary is downloaded from download.buildkite.com.

## Windows

Packer installs the `buildkite-agent` using the [`packer/windows/scripts/install-buildkite-agent.ps1`](packer/windows/scripts/install-buildkite-agent.ps1)
script. Update the `AGENT_VERSION` variable in this file to
change which version is installed.

The agent binary is downloaded from download.buildkite.com.
