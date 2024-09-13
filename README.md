<h1><img alt="Elastic CI Stack for AWS" src="images/banner.png?raw=true"></h1>

![Build status](https://badge.buildkite.com/d178ab942e2f606a83e79847704648437d82a9c5fdb434b7ae.svg?branch=main)

## Buildkite Elastic CI Stack for AWS

[Buildkite](https://buildkite.com/) is a platform for running fast, secure, and scalable continuous integration pipelines on your own infrastructure.

The Buildkite Elastic CI Stack for AWS gives you a private, autoscaling
[Buildkite Agent](https://buildkite.com/docs/agent) cluster. Use it to parallelize
large test suites across thousands of nodes, run tests and deployments for Linux or Windows
based services and apps, or run AWS ops tasks.

## Getting started

See the [Elastic CI Stack for AWS tutorial](https://buildkite.com/docs/guides/elastic-ci-stack-aws) for a step-by-step guide, the [Elastic CI Stack for AWS documentation](https://buildkite.com/docs/agent/v3/elastic-ci-aws), or the full [list of recommended resources](#recommended-reading) for detailed information.

Or jump straight in:

[![Launch AWS Stack](https://cdn.rawgit.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home#/stacks/new?stackName=buildkite&templateURL=https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml)

The current release is ![](https://img.shields.io/github/release/buildkite/elastic-ci-stack-for-aws.svg). See [Releases](https://github.com/buildkite/elastic-ci-stack-for-aws/releases) for older releases.

> Although the stack creates its own VPC by default, we highly recommend following best practice by setting up a separate development AWS account and using role switching and consolidated billing — see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

If you want to use the [AWS CLI](https://aws.amazon.com/cli/), download [`config.json.example`](config.json.example), rename it to `config.json`, and then run the below command:

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite \
  --template-url "https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml" \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
  --parameters "$(cat config.json)"
```

## Supported Features

Most features are supported across both Linux and Windows. See below for details
of per-operating system support:

Feature | Linux | Windows
--- | --- | ---
Docker | ✅ | ✅
Docker Compose | ✅ | ✅
AWS CLI | ✅ | ✅
S3 Secrets Bucket | ✅ | ✅
ECR Login | ✅ | ✅
Docker Login | ✅ | ✅
CloudWatch Logs Agent | ✅ | ✅
Per-Instance Bootstrap Script | ✅ | ✅
SSM Access | ✅ | ✅
Instance Storage (NVMe) | ✅ |
SSH Access | ✅ |
Periodic authorized_keys Refresh | ✅ |
Periodic Instance Health Check | ✅ |
git lfs | ✅ |
Additional sudo Permissions | ✅ |
RDP Access | | ✅
Pipeline Signing | ✅ | ✅

## Security

This repository hasn't been reviewed by security researchers so exercise caution and careful thought with what credentials you make available to your builds.

Anyone with commit access to your codebase (including third-party pull-requests if you've enabled them in Buildkite) will have access to your secrets bucket files.

Also keep in mind the EC2 HTTP metadata server is available from within builds, which means builds act with the same IAM permissions as the instance.

### Limiting CloudFormation Permissions

By default, CloudFormation will operate using the permissions granted to the
identity of the credentials used to initiate a stack deployment or update.

If you want to explicitly specify which actions CloudFormation can perform on
your behalf, you can either create your stack using credentials for an IAM
identity with limited permissions, or provide an [AWS CloudFormation service role](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-iam-servicerole.html).

🧑‍🔬 [templates/service-role.yml](templates/service-role.yml) template contains an
experimental service role and set of IAM Policies that list the IAM
Actions necessary to create, update, and delete a CloudFormation Stack created
with the Buildkite Elastic CI Stack template. The role created by this template
is currently being tested, but it has not been tested enough to be depended on.
There are likely to be missing permissions for some stack parameter
permutations.

```bash
aws cloudformation deploy --template-file templates/service-role.yml --stack-name buildkite-elastic-ci-stack-service-role --region us-east-1 --capabilities CAPABILITY_IAM
```

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

If you need to build your own AMI (because you've changed something in the
`packer` directory), run packer with AWS credentials in your shell environment:

```bash
make packer
```

This will boot and image three AWS EC2 instances in your account’s `us-east-1`
default VPC:

- Linux (64-bit x86)
- Linux (64-bit Arm)
- Windows (64-bit x86)

## Support Policy

We provide support for security and bug fixes on the current major release only.

If there are any changes in the main branch since the last tagged release, we
aim to publish a new tagged release of this template at the end of each month.

### AWS Regions

We support all AWS Regions, except China and US GovCloud.

We aim to support new regions within one month of general availability.

### Operating Systems

We build and deploy the following AMIs to all our supported regions:

- Amazon Linux 2023 (64-bit x86)
- Amazon Linux 2023 (64-bit Arm)
- Windows Server 2019 (64-bit x86)

### Buildkite Agent

The Elastic CI Stack template [published from the main branch](https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml)
tracks the latest Buildkite Agent release.

You may wish to preview any updates to your stack from this template
[using a CloudFormation Stack Change Set](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets.html)
to decide whether to apply it.

## Recommended reading

To gain a better understanding of how Elastic CI Stack works and how to use it most effectively and securely, see the following resources:

* [Elastic CI Stack for AWS overview](https://buildkite.com/docs/agent/v3/elastic_ci_aws)
* [Elastic CI Stack for AWS tutorial](https://buildkite.com/docs/tutorials/elastic-ci-stack-aws)
* [Running Buildkite Agent on AWS](https://buildkite.com/docs/agent/v3/aws)
* [Template parameters for Elastic CI Stack for AWS](https://buildkite.com/docs/agent/v3/elastic-ci-aws/parameters)
* [Using AWS Secrets Manager](https://buildkite.com/docs/agent/v3/aws/secrets-manager)
* [VPC Design](https://buildkite.com/docs/agent/v3/aws/vpc)
* [CloudFormation Service Role](https://buildkite.com/docs/agent/v3/elastic-ci-aws/cloudformation-service-role)

## Questions and support

Feel free to drop an email to support@buildkite.com with questions. It helps us if you can provide the following details:

```
# List your stack parameters
aws cloudformation describe-stacks --stack-name MY_STACK_NAME \
  --query 'Stacks[].Parameters[].[ParameterKey,ParameterValue]' --output table
```
### Collect logs from CloudWatch
Provide us with logs from CloudWatch Logs:

```
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
