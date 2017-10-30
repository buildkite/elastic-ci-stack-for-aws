# ECR Buildkite Plugin

__This is designed to run with Buildkite Agent v3.x beta. Plugins are not yet supported in Buildkite Agent v2.x.__

Login to ECR in your build steps.

## Example

This will login docker to ECR prior to running your script.

```yml
steps:
  - command: ./run_build.sh
    plugins:
      ecr#v1.0.0:
        login: true
```

## Options

### `login`

Whether to login to your account's ECR.

### `account-ids` (optional)

A list of AWS account IDs that correspond to the Amazon ECR registries that you want to log in to.

### `no-include-email` (optional)

Add `--no-include-email` to ecr get-login. Required for docker 17.06+, but needs aws-cli 1.11.91+.

## License

MIT (see [LICENSE](LICENSE))
