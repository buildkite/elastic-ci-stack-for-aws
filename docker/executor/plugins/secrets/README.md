# AWS S3 Secrets Buildkite Plugin

__This is designed to run with Buildkite Agent v3.x beta. Plugins are not yet supported in Buildkite Agent v2.x.__

Expose secrets to your build steps. Secrets are stored encrypted-at-rest in Amazon S3.

Different types of secrets are supported and exposed to your builds in appropriate ways:

- `ssh-agent` for SSH Private Keys
- Environment Variables for strings
- `git-credential` via git's credential.helper

## Example

The following pipeline downloads a private key from `s3://my-buildkite-secrets/{pipeline}/ssh_private_key` and set of environment variables from `s3://my-buildkite-secrets/{pipeline}/environment`.

The private key is exposed to both the checkout and the command as an ssh-agent instance. The secrets in the env file are exposed as environment variables.

```yml
steps:
  - command: ./run_build.sh
    plugins:
      s3-secrets#v1.3.0:
        bucket: my-buildkite-secrets
```

## Uploading Secrets

### SSH Keys

This example uploads an ssh key and an environment file to the root of the bucket, which means it matches all pipelines that use it. You use per-pipeline overrides by adding a path prefix of `/my-pipeline/`.

```bash
# generate a deploy key for your project
ssh-keygen -t rsa -b 4096 -f id_rsa_buildkite
pbcopy < id_rsa_buildkite.pub # paste this into your github deploy key

export secrets_bucket=my-buildkite-secrets
aws s3 cp --acl private --sse aws:kms id_rsa_buildkite "s3://${secrets_bucket}/private_ssh_key" 
```

### Git credentials

For git over https, you can use a `git-credentials` file with credential urls in the format of:

```
https://user:password@host/path/to/repo
```

```
aws s3 cp --acl private --sse aws:kms <(echo "https://user:password@host/path/to/repo") "s3://${secrets_bucket}/git-credentials" 
```

These are then exposed via a [gitcredential helper](https://git-scm.com/docs/gitcredentials) which will download the 
credentials as needed.

### Environment variables

Key values pairs can also be uploaded.

```
aws s3 cp --acl private --sse aws:kms <(echo "MY_SECRET=blah") "s3://${secrets_bucket}/environment" 
```

## Options

### `bucket`

An s3 bucket to look for secrets in. 

## License

MIT (see [LICENSE](LICENSE))
