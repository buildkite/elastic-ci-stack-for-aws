# Buildkite AWS Stack

This provides a way to run [isolated builds](https://buildkite.com/docs/guides/docker-containerized-builds) across a number of projects on the same servers, allowing large instances and more cost-saving strategies like spot instances to be employed.

## Prerequisites

  * An AWS account with EC2 and CloudFormation
  * [Amazon Commandline Interface](http://aws.amazon.com/cli/) installed and working
  * A git ssh key for checking out code called `id_rsa_buildkite` in an s3 bucket.

## Creating a stack

The `create-stack.sh` script will launch the cloudformation stack that powers your generic buildkite agents.

```bash
./create-stack.sh \
  BuildkiteOrgSlug=99designs \
  BuildkiteAgentToken=6a50625146693c3cef2a50f013bc3ed562a2ddba \
  KeyName=default \
  VpcId=vpc-ff95a89a \
  Subnets=subnet-1ac7a743,subnet-b8226dcf,subnet-f01c25ca \
  InstanceType=c4.2xlarge \
  BuildkiteQueue=loxtest \
  AuthorizedUsersUrl=https://example.org/authorized_keys
```

Check out `buildkite-elastic.yml` for what parameters are available. You can alternately upload the `cloudformation.json` file via the CloudFormation web interface.

## Project Configuration

### Targeting Builds with Agent Metadata

Your project needs to target whatever queue you setup with `BuildkiteQueue` in the stack creation, the default is `elastic`, so your agent metadata requirements would include `queue=elastic`.

If you have specific docker requirements, you can add in `docker=1.8`, which is currently what is supported. This allows for new docker versions to be incrementally added, so it's a good idea to include it.

### Isolating Builds with Docker

Whilst technically you could run commands directly on the hosts, it's a bad idea, because your build might affect the state of the machine (e.g installing packages, altering configuration). Instead it's strongly recommended that you use the build isolation mechanisms built into Buildkite:

Use docker-compose.yml file:

```
BUILDKITE_DOCKER_COMPOSE_CONTAINER=app
```

or a plain docker container:

```
BUILDKITE_DOCKER=true
```

### Passing in Credentials

The best way to get credentials such as Docker Hub login/pass to your builds is to pass them as environmental variables. If you provide `DOCKER_HUB_AUTH` as an env with the contents of your `~/.dockercfg` file, it will be written out before your build.
