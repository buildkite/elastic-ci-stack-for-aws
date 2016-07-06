# Buildkite AWS Elastic Stack

[![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg?branch=master)](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack)

A simple to setup auto-scaling build cluster running in your own AWS VPC. This single stack gives you a build cluster that all your projects can use, and allows you to massively parallelise any project that can be run with Docker Compose.

* All major AWS regions
* Use stable, unstable or experimental Buildkite Agent releases
* Choose any instance size you need
* Configurable number of agents per instance
* Custom scale-in/scale-in parameters
* Docker, Docker Compose and docker-gc
* Per-pipeline S3 secret storage (with encryption) for SSH keys and environment hooks
* Docker Hub credential login support for pushing images
* CloudWatch system and buildkite agent logs
* CloudWatch build metrics
* Spot instance pricing
* Test new build clusters by easily spinning up new instances of the stack

Although the stack is completely self-contained, and will create it's own VPC by default, we highly recommend following best practice by setting up a separate development AWS account and using role switching and consolidated billing—see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

## Getting Started

The easiest way is to launch the latest built version via this button:

[![Launch Buildkite AWS Stack](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/images/cloudformation-launch-stack-button.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json)

If you'd like to use the CLI, download [`config.json.example`](config.json.example) to `config.json` and then run the below command to create a new stack.

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json" \
  --capabilities CAPABILITY_IAM \
  --parameters <(cat config.json)
```

Alternately, if you prefer to use this repo, clone it and run the following command to set up things locally and create a remote stack.

```bash
# To set up your local environment and build a template based on public AMIs
make setup download-mappings build

# Or, to set things up locally and create the stack on AWS
make create-stack

# You can use any of the AWS... environment variables that the aws-cli supports.
AWS_PROFILE="SOMETHING" make create-stack
```

## Targeting Builds

Set your [Agent Query Rules](https://buildkite.com/docs/agent/agent-meta-data) to the `BuildkiteQueue` parameter you provided to your stack (e.g. `queue=elastic`)

## Secrets

Your stack has access to the `SecretsBucket` parameter you passed in. This should be used in combination with server-side object encryption to ensure that your CI secrets (such as Github credentials) are reasonably secure. See the [Security](#security) section for more details.

Two files are specifically looked for, `id_rsa_github`, for checking out your git code and optionally `env`, which contains environment variables to expose to the job command.

By default, builds will look for `s3://{SecretsBucket}/{PipelineSlug}/filename`.  You can override the `{PipelineSlug}` part with the `BUILDKITE_SECRETS_PREFIX` environment variable.

You should encrypt your objects with a project-specific key and provide it in `BUILDKITE_SECRETS_KEY` which will be used to decrypt all the files found in the secrets bucket.

### Creating a new project

```bash
# generate a deploy key for your project
ssh-keygen -t rsa -b 4096 -f id_rsa_github
pbcopy < id_rsa_github.pub # paste this into your github deploy key

# upload the private key, encrypted
PASSPHRASE=$(head -c 24  /dev/urandom | base64)
aws s3 cp --acl private --sse-c --sse-c-key "$PASSPHRASE" id_rsa_github "s3://my-provision-bucket/myproject/id_rsa_github"
pbcopy <<< "$PASSPHRASE" # paste passphrase into buildkite env as BUILDKITE_SECRETS_KEY

# cleanup
unset PASSPHRASE
rm id_rsa_github*
```

For Docker Hub credentials, you can use `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL` in your `env` file.

## Autoscaling

If you provided a `BuildkiteApiAccessToken` your build agents will autoscale. Autoscaling is designed to scale up quite quickly and then gradually scale down. See [the autoscale.yml template](templates/autoscale.yml) for more details, or the [Buildkite Metrics Publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) project for how metrics are collected. When scaling down, instances wait until any running jobs on them have completed (thanks to [lifecycled](https://github.com/lox/lifecycled)).

## Security

This repository hasn't been reviewed by security researchers, so exercise caution and careful thought with what credentials you make available to your builds. At present anyone with access to your CI machines or commit access to your codebase (including third-party pull-requests) will theoretically have access to your encrypted secrets. Anyone with access to your Buildkite Project Configuration will be able to retrieve the encryption key used to decrypt these. In combination, the attacker would have access to your decrypted secrets.

Presently the EC2 Metadata instance is available via HTTP request from builds, which means that builds have the same IAM access as the basic build host does.

## Questions?

This is currently in supported beta, and is under heavy use at 99designs and Buildkite.

Feel free to drop me an email to support@buildkite.com with questions, or checkout the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/).

