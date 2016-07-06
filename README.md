# Buildkite AWS Elastic Stack

[![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg?branch=master)](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack)

A simple to setup, best-practice, auto-scaling build cluster running in your own AWS VPC.

This stack is designed to run almost all of your organization’s projects, whether it’s legacy backend application tests parallelized across dozens or hundreds of agents for faster build times, or running ops-related tasks with your own tools or the `aws-cli`, you can run them all on this single stack.

* All major AWS regions
* Configurable instance size
* Configurable number of agents per instance
* Configurable spot instance bid price
* Configurable auto-scaling based on build activity
* Docker and Docker Compose support
* Per-pipeline S3 secret storage (with SSE encryption support)
* Docker Registry push/pull support
* CloudWatch logs for system and buildkite agent events
* CloudWatch metrics from the Buildkite API
* Support for stable, unstable or experimental Buildkite Agent releases

## Getting Started

The easiest way is to launch the latest built version via this button:

[![Launch Buildkite AWS Stack](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/images/cloudformation-launch-stack-button.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json)

> Although the stack will create it's own VPC by default, we highly recommend following best practice by setting up a separate development AWS account and using role switching and consolidated billing—see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

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

## What’s On Each Machine?

* [Amazon Linux](https://aws.amazon.com/amazon-linux-ami/)
* [Docker](https://www.docker.com)
* [Docker Compose](https://docs.docker.com/compose/)
* [aws-cli](https://aws.amazon.com/cli/) - useful for performing any ops-related tasks
* [jq](https://stedolan.github.io/jq/) - useful for manipulating JSON responses from cli tools such as aws-cli
* [docker-gc](https://github.com/spotify/docker-gc) - removes old docker images

## Targetting your Stack’s Agents

When you create the stack you specify a `BuildkiteQueue` parameter which is used to set agent’s queue, and ensures they will only accept jobs that specifically target them. This means you can easily experiment with entire new stacks without interuppting existing builds. See the [Agent Queues documentation](https://buildkite.com/docs/agent/queues) for how to target the agents in your pipelines.

Note that if you’ve set `MinInstances` to 0 then you won’t see any agents in Buildkite until you create build jobs, causing the autoscaling metrics to trigger a scale out event.

## Autoscaling

If you provided a `BuildkiteApiAccessToken` your build agents will autoscale. Autoscaling is designed to scale up quite quickly and then gradually scale down. See [the autoscale.yml template](templates/autoscale.yml) for more details, or the [Buildkite Metrics Publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) project for how metrics are collected. When scaling down, instances wait until any running jobs on them have completed (thanks to [lifecycled](https://github.com/lox/lifecycled)).

## Pipeline Configuration Environment Variables

The following environment variables can be set on the Buildkite pipeline or step to customize the behaviour of the stack:

* `BUILDKITE_SECRETS_BUCKET` - the name of the S3 bucket where secrets are stored. Default: the value set in the stack parameter when the stack was created. Example: `my-secrets-bucket`
* `BUILDKITE_SECRETS_KEY` - the encryption key used to decrypt objects from the secrets bucket. Default: nil. Example: `w2Uzhc4kXXbW//T9zaY3neoCbR9roQ10`
* `BUILDKITE_SECRETS_PREFIX` - the folder within the secrets bucket. Default: the build pipeline's slug. Example: `my-great-pipeline`
* `SSH_KEY_NAME` - the filename of the SSH key inside this pipeline’s folder in the secrets bucket. Default: `id_rsa`. Example: `id_rsa_github`
* `SHARED_SSH_KEY_NAME` - the filename of the SSH key in the root of the secrets bucket if there's no pipeline-specific SSH key present. Default: `id_rsa`. Example: `id_rsa_github_shared`

## Secrets Bucket Support

The stack has a `SecretsBucket` parameter which will allow your build agents to automatically get access to SSH private keys and environment hooks for exposing environment variables to builds. The stack doesn't create the bucket for you, you need to do this yourself, but it does create a role that gives read access to the build machines. 

The secrets bucket can contain the following files:

* `/id_sra` - An optional private key to use Git SSH operations when there is no pipeline-specific key present
* `/{PipelineSlug}/env` - An optional bash script to use as an [agent environment hook](https://buildkite.com/docs/agent/hooks)
* `/{PipelineSlug}/id_rsa` - An optional pipeline-specific private key to use for Git SSH operations

The files in your secrets bucket should be encrypted with server-side object encryption to ensure they are reasonably secure. See the [Security](#security) section for more details.

Encryption is done via the `BUILDKITE_SECRETS_KEY` environment variable set via the Buildkite pipeline settings, and can be the same, or different, for each pipeline.

Here’s an an example (for OS X) that shows how to create a new private SSH key, generate and copy a random passphrase for S3 encryption, and upload an encypted version of the key to your S3 bucket:

```bash
# generate a deploy key for your project
ssh-keygen -t rsa -b 4096 -f id_rsa_buildkite
pbcopy < id_rsa_buildkite.pub # paste this into your github deploy key

# upload the private key, encrypted
PASSPHRASE=$(head -c 24 /dev/urandom | base64)
aws s3 cp --acl private --sse-c --sse-c-key "$PASSPHRASE" id_rsa_buildkite "s3://{SecretsBucket}/{PipelineSlug}/id_rsa"
pbcopy <<< "$PASSPHRASE" # paste passphrase into buildkite env as BUILDKITE_SECRETS_KEY

# cleanup
unset PASSPHRASE
rm id_rsa_buildkite*
```

## Docker Registry Support

If you want to push or pull from Docker Hub you can use the `env` file in your secrets bucket to export `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL`. This will perform a `docker login` before each pipeline step is run, allowing you to `docker push` to Docker Hub.

If you want to use [AWS ECR](https://aws.amazon.com/ecr/) instead of Docker Hub there's no need to worry about credentials, you simply ensure that your agent machines have the necessary IAM roles and permissions.

For all other services you’ll need to perform your own `docker login` commands using the `env` hook.

## Security

This repository hasn't been reviewed by security researchers, so exercise caution and careful thought with what credentials you make available to your builds. At present anyone with access to your CI machines or commit access to your codebase (including third-party pull-requests) will theoretically have access to your encrypted secrets. Anyone with access to your Buildkite Project Configuration will be able to retrieve the encryption key used to decrypt these. In combination, the attacker would have access to your decrypted secrets.

Presently the EC2 Metadata instance is available via HTTP request from builds, which means that builds have the same IAM access as the basic build host does.

## Questions?

This is currently in supported beta, and is under heavy use at 99designs and Buildkite.

Feel free to drop me an email to support@buildkite.com with questions, or checkout the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/).

