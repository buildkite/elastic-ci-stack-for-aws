# Updating elastic-ci-stack-s3secrets-hooks

The elastic-ci-stack-s3secrets-hooks are included in the AMIs by the Packer
build. The hooks are copied in directly from the submodule, the binaries are
downloaded from the GitHub release.

See https://github.com/buildkite/elastic-ci-stack-for-aws/pull/956 for an
example of updating elastic-ci-stack-s3secrets-hooks.

1. Create a new branch
1. Update the `plugins/secrets` git submodule and `.gitmodules` file for the new tag
	1. `git submodule init`
	1. `cd plugins/secrets && git checkout v2.1.x`
1. Commit the change to the submodule pin and `.gitmodules`
1. Update and commit a change to the Packer install scripts for [Linux](#linux) and [Windows](#windows) to use the new version
1. Push your branch and open a pull request
1. Wait for CI to go green
1. Merge

## Linux

Update `S3_SECRETS_HELPER_VERSION` in [`packer/linux/scripts/install-s3secrets-helper.sh`](packer/linux/scripts/install-s3secrets-helper.sh)

## Windows

Update `S3_SECRETS_HELPER_VERSION` in [`packer/windows/scripts/install-s3secrets-helper.ps1`](packer/windows/scripts/install-s3secrets-helper.ps1)
