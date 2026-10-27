# Updating elastic-ci-stack-s3secrets-hooks

Packer copies hooks from `plugins/secrets` into the AMIs and downloads helper
binaries separately. Renovate groups the submodule and Linux/Windows helper
updates in one `s3-secrets` PR on the monthly schedule. Check that they target
the same release before merging.

## Manual updates

Confirm the [release](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/releases)
includes `linux-amd64`, `linux-arm64`, and `windows-amd64` binaries, then:

1. Update the submodule tag and checkout (replace `v2.9.1` as needed):

   ```sh
   git submodule update --init plugins/secrets
   git config -f .gitmodules submodule.plugins/secrets.branch v2.9.1
   git -C plugins/secrets fetch origin tag v2.9.1
   git -C plugins/secrets checkout --detach v2.9.1
   ```

1. Set `S3_SECRETS_HELPER_VERSION` to the same version without `v` in:
   - [`packer/linux/base/scripts/versions.sh`](../packer/linux/base/scripts/versions.sh)
   - [`packer/windows/base/scripts/versions.ps1`](../packer/windows/base/scripts/versions.ps1)
1. Commit `.gitmodules`, `plugins/secrets`, and both version files together.
   Open a PR and wait for CI before merging.
