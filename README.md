<h1><img alt="Elastic CI Stack for AWS" src="https://cdn.rawgit.com/buildkite/buildkite-aws-elastic-stack/504f362/logo.svg" width="770" height="150"></h1>

[![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg?branch=master)](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack)

The Buildkite Elastic CI Stack gives you a private, autoscaling [Buildkite Agent](https://buildkite.com/docs/agent) cluster. Use it to parallelize legacy tests across hundreds of nodes, run tests and deployments for all your Linux-based services and apps, or run AWS ops tasks.

Features:

- All major AWS regions
- Configurable instance size
- Configurable number of buildkite agents per instance
- Configurable spot instance bid price
- Configurable auto-scaling based on build activity
- Docker and Docker Compose support
- Per-pipeline S3 secret storage (with SSE encryption support)
- Docker Registry push/pull support
- CloudWatch logs for system and buildkite agent events
- CloudWatch metrics from the Buildkite API
- Support for stable, unstable or experimental Buildkite Agent releases
- Create as many instances of the stack as you need
- Rolling updates to stack instances to reduce interruption

## Contents

<!-- toc -->

- [Getting Started](#getting-started)
- [What’s On Each Machine?](#what’s-on-each-machine)
- [Running Builds on your Stack](#running-builds-on-your-stack)
- [Autoscaling Configuration](#autoscaling-configuration)
- [Pipeline Configuration Environment Variables](#pipeline-configuration-environment-variables)
- [Secrets Bucket Support](#secrets-bucket-support)
- [Docker Registry Support](#docker-registry-support)
- [Reading Instance and Agent Logs](#reading-instance-and-agent-logs)
- [Optimizing for Slow Docker Builds](#optimizing-for-slow-docker-builds)
- [Security](#security)
- [Questions?](#questions)
- [Licence](#licence)

<!-- tocstop -->

## Getting Started

The latest build of the stack template can be launched in your AWS account with the following button:

[![Launch Buildkite AWS Stack](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/images/cloudformation-launch-stack-button.png)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json)

> Although the stack will create it's own VPC by default, we highly recommend following best practice by setting up a separate development AWS account and using role switching and consolidated billing—see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

If you'd like to use the [AWS CLI](https://aws.amazon.com/cli/), download [`config.json.example`](config.json.example), rename it to `config.json`, and then run the below command:

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json" \
  --capabilities CAPABILITY_IAM \
  --parameters <(cat config.json)
```

If you’d prefer to use this repo or build it yourself, clone it and run the following commands:

```bash
# To set up your local environment and build a template based on public AMIs
make setup download-mappings build

# Or, to set things up locally and create the stack on AWS
make create-stack

# You can use any of the AWS* environment variables that the aws-cli supports
AWS_PROFILE="some-profile" make create-stack

# You can also use aws-vault or similar
aws-vault exec some-profile -- make create-stack
```

## What’s On Each Machine?

* [Amazon Linux](https://aws.amazon.com/amazon-linux-ami/)
* [Buildkite Agent](https://buildkite.com/docs/agent)
* [Docker](https://www.docker.com)
* [Docker Compose](https://docs.docker.com/compose/)
* [aws-cli](https://aws.amazon.com/cli/) - useful for performing any ops-related tasks
* [jq](https://stedolan.github.io/jq/) - useful for manipulating JSON responses from cli tools such as aws-cli or the Buildkite API
* [docker-gc](https://github.com/spotify/docker-gc) - removes old docker images
* [lifecycled](https://github.com/lox/lifecycled) - manages AWS autoscaling events

## Running Builds on your Stack

When you create the stack you specify a `BuildkiteQueue` parameter which is used to set agent’s queue, and ensures they will only accept jobs that specifically target them. This means you can easily experiment with entire new stacks without interuppting existing builds. See the [Agent Queues documentation](https://buildkite.com/docs/agent/queues) for how to target the agents in your pipelines.

Note that if you’ve set `MinInstances` to 0 then you won’t see any agents in Buildkite until you create build jobs, causing the autoscaling metrics to trigger a scale out event.

## Autoscaling Configuration

If you provided a `BuildkiteApiAccessToken` your build agents will autoscale. Autoscaling is designed to scale up quite quickly and then gradually scale down. When scaling down, instances wait until any running jobs on them have completed.

See [the autoscale.yml template](templates/autoscale.yml) for more details, or the [Buildkite Metrics Publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) project for how metrics are collected. 

## Pipeline Configuration Environment Variables

The following environment variables can be set on the Buildkite pipeline or step to customize the behaviour of the stack:

* `BUILDKITE_SECRETS_BUCKET` - the name of the S3 bucket where secrets are stored. Default: the value set in the stack parameter when the stack was created. Example: `my-secrets-bucket`
* `BUILDKITE_SECRETS_KEY` - the encryption key used to decrypt objects from the secrets bucket. Default: nil. Example: `w2Uzhc4kXXbW//T9zaY3neoCbR9roQ10`
* `BUILDKITE_SECRETS_PREFIX` - the folder within the secrets bucket. Default: the build pipeline's slug. Example: `my-great-pipeline`
* `SSH_KEY_NAME` - the filename of the SSH key inside this pipeline’s folder in the secrets bucket. Default: `private_ssh_key`. Example: `other_ssh_key`
* `SHARED_SSH_KEY_NAME` - the filename of the SSH key in the root of the secrets bucket if there's no pipeline-specific SSH key present. Default: `private_ssh_key`. Example: `other_ssh_key`

## Secrets Bucket Support

The stack has a `SecretsBucket` parameter which will allow your build agents to automatically get access to SSH private keys and environment hooks for exposing environment variables to builds. The stack doesn't create the bucket for you, you need to do this yourself, but it does create a role that gives read access to the build machines. 

The secrets bucket can contain the following files:

* `/private_ssh_key` - An optional private key to use for Git SSH operations when there is no pipeline-specific key present
* `/{pipeline-slug}/env` - An optional bash script to use as an [agent environment hook](https://buildkite.com/docs/agent/hooks)
* `/{pipeline-slug}/private_ssh_key` - An optional pipeline-specific private key to use for Git SSH operations

The files in your secrets bucket should be encrypted with server-side object encryption to ensure they are reasonably secure. See the [Security](#security) section for more details.

Encryption is done via the `BUILDKITE_SECRETS_KEY` environment variable set via the Buildkite pipeline settings, and can be the same, or different, for each pipeline.

Here’s an an example (for OS X) that shows how to create and copy a random encyption passphrase, generate a private SSH key, and upload it with SSE encryption to an S3 bucket:

```bash
# generate a deploy key for your project
ssh-keygen -t rsa -b 4096 -f id_rsa_buildkite
pbcopy < id_rsa_buildkite.pub # paste this into your github deploy key

# upload the private key, encrypted
PASSPHRASE=$(head -c 24 /dev/urandom | base64)
aws s3 cp --acl private --sse-c --sse-c-key "$PASSPHRASE" id_rsa_buildkite "s3://{SecretsBucket}/private_ssh_key"
pbcopy <<< "$PASSPHRASE" # paste passphrase into buildkite env as BUILDKITE_SECRETS_KEY

# cleanup
unset PASSPHRASE
rm id_rsa_buildkite*
```

## Docker Registry Support

If you want to push or pull from Docker Hub you can use the `env` file in your secrets bucket to export `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL`. This will perform a `docker login` before each pipeline step is run, allowing you to `docker push` to Docker Hub.

If you want to use [AWS ECR](https://aws.amazon.com/ecr/) instead of Docker Hub there's no need to worry about credentials, you simply ensure that your agent machines have the necessary IAM roles and permissions.

For all other services you’ll need to perform your own `docker login` commands using the `env` hook.

## Reading Instance and Agent Logs

Each instance streams both system messages and Buildkite Agent logs to CloudWatch Logs under two log groups:

* `/var/log/messages` - system logs
* `/var/log/buildkite-agent.log` - Buildkite Agent logs

Within each stream the logs are grouped by instance id.

To debug an agent first find the instance id from the agent in Buildkite, head to your [CloudWatch Logs Dashboard](https://console.aws.amazon.com/cloudwatch/home?#logs:), choose either the system or Buildkite Agent log group, and then search for the instance id in the list of log streams.

## Optimizing for Slow Docker Builds

For large legacy applications the Docker build process might take a long time on new instances. For these cases it’s recommended to create an optimized "builder" stack which doesn't scale down, keeps a warm docker cache, is responsible for building and pushing the application to Docker Hub before running the parallel build jobs across your normal CI stack.

To use this type of setup:

1. Create a Docker Hub repository for pushing images to
1. Create a builder stack with its own queue (i.e. `elastic-builders`)
1. Use the Buildkite Agent `beta` release stream in your stacks (so you can use the [https://github.com/buildkite-plugins/docker-compose-buildkite-plugin](Docker Compose Buildkite Plugin) and [pre-building](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin#pre-building-the-image)

Here is an example build pipeline based on a production Rails application:

```yaml
steps:
  - name: ":docker: :package:"
    plugins:
      docker-compose:
        build: app
        image-repository: index.docker.io/my-docker-org/my-repo
    agents:
      queue: elastic-builders
  - wait
  - name: ":hammer:"
    command: ".buildkite/steps/tests"
    plugins:
      docker-compose:
        run: app
    agents:
      queue: elastic
    parallelism: 75
```

See [Issue 81](https://github.com/buildkite/elastic-ci-stack-for-aws/issues/81) for ideas on other solutions (contributions welcome!).

## Security

This repository hasn't been reviewed by security researchers so exercise caution and careful thought with what credentials you make available to your builds.

Anyone with commit access to your codebase (including third-party pull-requests if you've enabled them in Buildkite) will have access to your secrets bucket files, and anyone with access to the Buildkite pipeline settings will be able to access the pipeline’s secrets encryption key. In combination, the attacker would have access to your decrypted secrets.

Also keep in mind the EC2 HTTP metadata server is available from within builds, which means builds act with the same IAM permissions as the instance.

## Questions?

Feel free to drop me an email to support@buildkite.com with questions, or checkout the `#aws-stack` and `#aws` channels in [Buildkite Slack](https://chat.buildkite.com/).

## Licence

See [Licence.md](Licence.md) (MIT)