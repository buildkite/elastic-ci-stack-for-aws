# Buildkite AWS Stack

An Amazon CloudFormation stack for running an auto-scaling group of EC2 instances with Buildkite agents on them. Designed to support multiple different projects sharing a single stack and isolated builds of third-party pull-requests.

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
| ProvisionBucket              | An S3 bucket and prefix that contains your credentials/keys          |                 |
| InstanceType                 | The EC2 instance size to launch                                      | t2.nano         |
| MinSize                      | The minimum number of instances to launch                            | 1               |
| MaxSize                      | The maximum number of instances to launch                            | 1               |

Check out [`buildkite-elastic.yml`](templates/buildkite-elastic.yml) for more details.

## Targeting Builds

Set your [Agent Query Rules](https://buildkite.com/docs/agent/agent-meta-data) to `queue=elastic`, or to whatever `BuildkiteQueue` you provided to your stack.

## Credentials

Your stack has access to the `ProvisionBucket` parameter you passed in, you can use this to get a GitHub SSH key to the build and soon will be able to use it to get generic credentials there too.

For now, upload your GitHub key to the bucket, which should be private by default.

For Docker Hub credentials, you can use `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL`.

```bash
aws s3 cp --acl private my_id_rsa_key "s3://my-provision-bucket/id_rsa_github"
```

Then in your Buildkite environment variables, set `SSH_KEY_URL` to `s3://my-provision-bucket/id_rsa_github`.

## Questions?

This is experimental and still being actively developed, but under heavy use at 99designs.

Feel free to drop me an email at lachlan@99designs.com with questions, or checkout the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/).