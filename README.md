# Buildkite AWS Stack

[![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg)](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack)

Create an auto-scaling build cluster on AWS/VPC in under 10 minutes. Designed to support multiple different projects sharing a single stack and isolated builds of third-party pull-requests.

## Getting Started

The easiest way is to launch the latest built version via this button:

[![Launch Buildkite AWS Stack](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/images/cloudformation-launch-stack-button.png)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json)

If you'd like to use the CLI, download [`config.json.example`](config.json.example) to `config.json` and then run the below command to create a new stack.

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/aws-stack.json" \
  --capabilities CAPABILITY_IAM \
  --parameters <(cat config.json)
```

### Useful Stack Parameters

| Command                      | Description                                                          | Default         |
| ---                          | ---                                                                  | ---             |
| KeyName                      | The AWS EC2 Keypair to use                                           | default         |
| BuildkiteOrgSlug             | Your Buildkite Organization slug (e.g 99designs)                     |                 |
| BuildkiteAgentToken          | Your Buildkite Agent Token                                           |                 |
| BuildkiteQueue               | The Buildkite queue to give the agents                               | elastic         |
| SecretsBucket                | An S3 bucket (and optional prefix) that contains secrets             |                 |
| InstanceType                 | The EC2 instance size to launch                                      | t2.nano         |
| MinSize                      | The minimum number of instances to launch                            | 1               |
| MaxSize                      | The maximum number of instances to launch                            | 1               |
| SpotPrice                    | An optional price to bid for spot instances (0 means non-spot)       | 0               |
| AutoscalingStrategy          | Either cpu or scheduledjobs (see [Autoscaling](#autoscaling))        | cpu             |


Check out [`buildkite-elastic.yml`](templates/buildkite-elastic.yml) for more details.

## Targeting Builds

Set your [Agent Query Rules](https://buildkite.com/docs/agent/agent-meta-data) to `queue=elastic`, or to whatever `BuildkiteQueue` you provided to your stack.

## Secrets

Your stack has access to the `SecretsBucket` parameter you passed in. This should be used in combination with server-side object encryption to ensure that your CI secrets (such as Github credentials) are reasonably secure. See the [Security](#security) section for more details.

Two files are specifically looked for, `id_rsa_github`, for checking out your git code and optionally `env`, which contains environment variables to expose to the job command.

By default, builds will look for `s3://{SecretsBucket}/{PipelineSlug}/filename`.  You can override the `{PipelineSlug}` part with the `BUILDKITE_SECRETS_PREFIX` environment variable.

You should encrypt your objects with a project-specific key and provide it in `BUILDKITE_SECRETS_KEY` which will be used to decrypt all the files found in the secrets bucket.

### Uploading your Secrets

```bash
PASSPHRASE=$(head -c 24  /dev/urandom | base64)
aws s3 cp --acl private --sse-c --sse-c-key "$PASSPHRASE" my_id_rsa_key "s3://my-provision-bucket/myproject/id_rsa_github"
```

For Docker Hub credentials, you can use `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL` in your `env` file.

## Autoscaling

Autoscaling behaviour is determined by a number of stack parameters. By default your stack will have between 1 and 6 instances and scale based on the CPU load of the instances. The threshold for CPU scaling is [40% cpu load for 5 minutes](templates/autoscale.yml), which at present isn't customizable.

If you want to get fancy, you can set up the [Buildkite Metrics Publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) which publishes custom CloudWatch metrics every 5 minutes. If you set the stack param `AutoscalingStrategy` to `scheduledjobs` then your stack will be scaled based on the number of scheduled jobs in it's queue (determined by `BuildkiteQueue`). You can even set the `MinSize` to 0 if you want to keep costs down, but be mindful of the 5 minute lag time on a new instance spinning up to run your build.

## Security

This repository hasn't been reviewed by security researchers, so exercise caution and careful thought with what credentials you make available to your builds. At present anyone with access to your CI machines or commit access to your codebase (including third-party pull-requests) will theoretically have access to your encrypted secrets. Anyone with access to your Buildkite Project Configuration will be able to retrieve the encryption key used to decrypt these. In combination, the attacker would have access to your decrypted secrets.

Presently the EC2 Metadata instance is available via HTTP request from builds, which means that builds have the same IAM access as the basic build host does.

## Questions?

This is experimental and still being actively developed, but under heavy use at 99designs.

Feel free to drop me an email at lachlan@99designs.com with questions, or checkout the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/).

