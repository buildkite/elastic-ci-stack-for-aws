<h1><img alt="Elastic CI Stack for AWS" src="images/banner.png?raw=true"></h1>

[![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg?branch=main)](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack/builds/latest?branch=main)

## Buildkite Elastic CI Stack for AWS

> [!NOTE]
> Prefer Terraform? See [terraform-buildkite-elastic-ci-stack-for-aws](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws)

[Buildkite](https://buildkite.com/) provides a platform for running fast, secure, and scalable continuous integration pipelines on your own infrastructure.

The Buildkite Elastic CI Stack for AWS gives you a private, autoscaling [Buildkite Agent](https://buildkite.com/docs/agent) cluster. Use it to parallelize large test suites across thousands of nodes, run tests and deployments for Linux or Windows based services and apps, or run AWS ops tasks.

## Getting started

Learn more about the Elastic CI Stack for AWS and how to get started with it from the Buildkite Docs:

- [Elastic CI Stack for AWS overview](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack) page, for a summary of the stack's architecture and supported features.
- [Linux and Windows setup for the Elastic CI Stack for AWS](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/setup) page for a step-by-step guide on how to set up the Elastic CI Stack in AWS for these operating systems.

A [list of recommended resources](#recommended-reading) provides links to other pages in the Buildkite Docs for more detailed information.

Alternatively, jump straight in:

[![Launch AWS Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml)

The current release is ![](https://img.shields.io/github/release/buildkite/elastic-ci-stack-for-aws.svg). See [Releases](https://github.com/buildkite/elastic-ci-stack-for-aws/releases) for older releases.

> Although the stack creates its own VPC by default, Buildkite highly recommends following best practices by setting up a separate development AWS account and using role switching and consolidated billing — see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

If you want to use the [AWS CLI](https://aws.amazon.com/cli/), download [`config.json.example`](config.json.example), rename it to `config.json`, update it with your agent token, then run the below AWS CLI command to create the AWS CloudFormation stack:

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameters "$(cat config.json)"
```

## Security

This repository hasn't been reviewed by security researchers. Therefore, exercise caution and careful thought with what credentials you make available to your builds.

Anyone with commit access to your codebase (including third-party pull-requests if you've enabled them in Buildkite) will have access to your secrets bucket files.

Also, keep in mind the EC2 HTTP metadata server is available from within builds, which means builds act with the same IAM permissions as the instance.

### Limiting CloudFormation Permissions

By default, CloudFormation will operate using the permissions granted to the identity of the credentials used to initiate a stack deployment or update.

If you want to explicitly specify which actions CloudFormation can perform on your behalf, you can either create your stack using credentials for an IAM identity with limited permissions, or provide an [AWS CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html).

🧑‍🔬 [templates/service-role.yml](templates/service-role.yml) template contains an experimental service role and set of IAM Policies that list the IAM Actions necessary to create, update, and delete a CloudFormation Stack created with the Buildkite Elastic CI Stack template. The role created by this template is currently being tested, but it has not been tested enough to be depended on. There are likely to be missing permissions for some stack parameter permutations.

```bash
aws cloudformation deploy --template-file templates/service-role.yml --stack-name buildkite-elastic-ci-stack-service-role --region us-east-1 --capabilities CAPABILITY_IAM
```

## Experimental Resource Limits

The Elastic CI Stack includes configurable systemd resource limits to prevent resource exhaustion. These limits can be configured using CloudFormation parameters:

| Parameter                          | Description                                            | Default |
|------------------------------------|--------------------------------------------------------|---------|
| `ExperimentalEnableResourceLimits` | Enable systemd resource limits for the Buildkite agent | `false` |
| `ResourceLimitsMemoryHigh`         | MemoryHigh limit (e.g., '90%' or '4G')                 | `90%`   |
| `ResourceLimitsMemoryMax`          | MemoryMax limit (e.g., '90%' or '4G')                  | `90%`   |
| `ResourceLimitsMemorySwapMax`      | MemorySwapMax limit (e.g., '90%' or '4G')              | `90%`   |
| `ResourceLimitsCPUWeight`          | CPU weight (1-10000)                                   | `100`   |
| `ResourceLimitsCPUQuota`           | CPU quota (e.g., '90%')                                | `90%`   |
| `ResourceLimitsIOWeight`           | I/O weight (1-10000)                                   | `80`    |

### Example Configuration

To enable resource limits with custom values, include these parameters in your CloudFormation template or config file:

```yaml
{
  "Parameters": {
    "ExperimentalEnableResourceLimits": "true",
    "ResourceLimitsMemoryHigh": "80%",
    "ResourceLimitsMemoryMax": "85%",
    "ResourceLimitsMemorySwapMax": "90%",
    "ResourceLimitsCPUWeight": "100",
    "ResourceLimitsCPUQuota": "85%",
    "ResourceLimitsIOWeight": "75"
  }
}
```

### Notes
- Resource limits are disabled by default
- Values can be specified as percentages or absolute values (for memory-related parameters)

## Scheduled Scaling

The Elastic CI Stack supports time-based scaling to automatically adjust the minimum number of instances based on your team's working hours. This feature helps optimize costs by scaling down during off-hours while allowing users the ability to proactively scale up capacity ahead of expected increasing capacity requirements.

### Configuration Parameters

| Parameter                | Description                                          | Default              |
|--------------------------|------------------------------------------------------|----------------------|
| `EnableScheduledScaling` | Enable scheduled scaling actions                     | `false`              |
| `ScheduleTimezone`       | Timezone for scheduled actions                       | `UTC`                |
| `ScaleUpSchedule`        | Cron expression for scaling up                       | `0 8 * * MON-FRI`    |
| `ScaleUpMinSize`         | MinSize when scaling up                              | `1`                  |
| `ScaleDownSchedule`      | Cron expression for scaling down                     | `0 18 * * MON-FRI`   |
| `ScaleDownMinSize`       | MinSize when scaling down                            | `0`                  |

### Example Configuration

To enable scheduled scaling that maintains a minimum of 10 ASG instances during business hours (8 AM - 6 PM, Eastern Time) and 2 ASG instances during off-hours:

```json
{
  "Parameters": {
    "EnableScheduledScaling": "true",
    "ScheduleTimezone": "America/New_York",
    "ScaleUpSchedule": "0 8 * * MON-FRI",
    "ScaleUpMinSize": "10",
    "ScaleDownSchedule": "0 18 * * MON-FRI",
    "ScaleDownMinSize": "2"
  }
}
```

### Schedule Format

Scheduled scaling uses [AWS Auto Scaling cron expressions](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron) with the format:
```
minute hour day-of-month month day-of-week
```

Common examples:
- `0 8 * * MON-FRI` - 8:00 AM on weekdays
- `0 18 * * MON-FRI` - 6:00 PM on weekdays
- `0 9 * * SAT` - 9:00 AM on Saturdays
- `30 7 * * 1-5` - 7:30 AM Monday through Friday (using numbers)

### Timezone Support

The `ScheduleTimezone` parameter supports [IANA timezone names](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-timezone) such as:
- `America/New_York` (Eastern Time)
- `America/Los_Angeles` (Pacific Time)
- `Europe/London` (Greenwich Mean Time)
- `Asia/Tokyo` (Japan Standard Time)
- `UTC` (Coordinated Universal Time)

## Development

To get started with customizing your own stack, or contributing fixes and features:

```bash
# Checkout all submodules
git submodule update --init --recursive

# Build all AMIs and render a cloud formation template - this requires AWS credentials (in the ENV)
# to build an AMI with packer
make build

# To create a new stack on AWS using the local template
make create-stack

# You can use any of the AWS* environment variables that the aws-cli supports
AWS_PROFILE="some-profile" make create-stack

# You can also use aws-vault or similar
aws-vault exec some-profile -- make create-stack
```

If you need to build your own AMIs (because you've changed something in the
`packer` directory), run `make packer` with AWS credentials in your shell environment.

The build process is now two steps:
1.  **Base AMI:** A base AMI is created with the latest OS updates. This image is cached and only rebuilt when the underlying OS or configuration changes.
2.  **Final AMI:** The final AMI is built on top of the base AMI, installing the Buildkite agent and other software. This makes final builds faster and more consistent.

By default, AMIs are built as private. You can control AMI visibility and build location using these variables:

- `AMI_PUBLIC` - Set to `true` to make AMIs publicly accessible to all AWS users, or `false` (default) for private AMIs.
- `AMI_USERS` - A comma-separated list of AWS account IDs that should have access to private AMIs (ignored when `AMI_PUBLIC=true`).
- `AWS_REGION` - The AWS region where AMIs should be built (defaults to `us-east-1`).

```bash
# Build private AMIs (default - recommended for security)
make packer

# Build public AMIs (available to all AWS users)
make packer AMI_PUBLIC=true

# Build private AMIs with access for specific AWS accounts
make packer AMI_USERS="123456789012,987654321098,555666777888"

# Combined: private AMIs with specific account access in a different region
make packer AMI_PUBLIC=false AMI_USERS="123456789012,987654321098" AWS_REGION=us-west-2
```

This will create AMIs for the following platforms in your account's `us-east-1` region (or the region specified by `AWS_REGION`):

- Linux (64-bit x86)
- Linux (64-bit Arm)
- Windows (64-bit x86)

If you only need Linux AMIs, invoke the specific targets to skip the Windows build:

```bash
# Linux amd64 (x86_64)
make packer-base-linux-amd64.output packer-linux-amd64.output

# Linux arm64
make packer-base-linux-arm64.output packer-linux-arm64.output

# Both Linux architectures
make packer-base-linux-amd64.output packer-linux-amd64.output \
     packer-base-linux-arm64.output packer-linux-arm64.output
```

**Security Note:** Making AMIs public (`AMI_PUBLIC=true`) can expose any secrets accidentally baked into the image. The default private setting helps prevent accidental exposure of sensitive information.

## Support Policy

We provide support for security and bug fixes on the current major release only.

If there are any changes in the main branch since the last tagged release, we
aim to publish a new tagged release of this template at the end of each month.

### AWS Regions

Buildkite:

- Supports all AWS Regions, except China and US GovCloud.
- Aims to support new regions within one month of general availability.

### Operating Systems

Buildkite builds and deploys the following AMIs to all our supported regions:

- Amazon Linux 2023 (64-bit x86)
- Amazon Linux 2023 (64-bit Arm)
- Windows Server 2022 (64-bit x86)

### Buildkite Agent

The Elastic CI Stack template [published from the main branch](https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml)
tracks the latest Buildkite Agent release.

You may wish to preview any updates to your stack from this template
[using a CloudFormation Stack Change Set](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets.html)
to decide whether to apply it.

## Recommended reading

Following on from the [Getting started](#getting-started) pages above, to gain a better understanding of how Elastic CI Stack works and how to use it most effectively and securely, see the following resources:

- [Buildkite Agents in AWS overview](https://buildkite.com/docs/agent/v3/aws)
- [Template parameters](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/template-parameters)
- [Using AWS Secrets Manager](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/secrets-manager)
- [VPC design](https://buildkite.com/docs/agent/v3/aws/architecture/vpc)
- [CloudFormation service role](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/cloudformation-service-role)

## Questions and support

Feel free to drop an email to support@buildkite.com with questions. It'll also help us if you can provide the following details:

```bash
# List your stack parameters
aws cloudformation describe-stacks --stack-name MY_STACK_NAME \
  --query 'Stacks[].Parameters[].[ParameterKey,ParameterValue]' --output table
```

### Collect logs from CloudWatch

Provide Buildkite with logs from CloudWatch Logs:

```bash
/buildkite/elastic-stack/{instance-id}
/buildkite/system/{instance-id}
```

### Collect logs via script

An alternative method to collect the logs is to use the `log-collector` script in the `utils` folder.
The script will collect CloudWatch logs for the Instance, Lambda function, and AutoScaling activity and package them in a
zip archive which you can send via email to support@buildkite.com.

You can also visit our [Forum](https://forum.buildkite.community) and post a question in the [Elastic CI Stack for AWS](https://forum.buildkite.community/c/elastic-ci-stack-for-aws/) section!

## Licence

See [Licence.md](Licence.md) (MIT)
