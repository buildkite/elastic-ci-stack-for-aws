# Updating the Agent

## Linux

Packer installs the `buildkite-agent` using the [`packer/linux/scripts/install-buildkite-agent.sh`](packer/linux/scripts/install-buildkite-agent.sh)
script.

The agent binary is downloaded from download.buildkite.com.

Update the `AGENT_VERSION` variable to change which version is installed.

## Windows

Packer installs the `buildkite-agent` using the [`packer/windows/scripts/install-buildkite-agent.ps1`](packer/windows/scripts/install-buildkite-agent.ps1)
script.

The agent binary is downloaded from download.buildkite.com.

Update the `AGENT_VERSION` variable to change which version is installed.
