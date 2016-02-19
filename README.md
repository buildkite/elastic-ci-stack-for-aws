# Buildkite AWS Stack

This provides a way to run [isolated builds](https://buildkite.com/docs/guides/docker-containerized-builds) across a number of projects on the same AWS instances, allowing large instance sizes and auto-scaling for better utilization and cost-efficiency.

## Status

Experimental. Still being actively developed, but under heavy use at 99designs.

Feel free to drop me an email at lachlan@99designs.com with questions, or checkout the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/).

## Prerequisites

  * An AWS account with EC2 and CloudFormation
  * [Amazon Commandline Interface](http://aws.amazon.com/cli/) installed and working

## Install

```
make setup clean build
```

## Creating a stack

Copy over [`config.json.example`](config.json.example) to `config.json` and then run the below command to create a new stack.

```bash
aws cloudformation create-stack \
  --output text \
  --stack-name buildkite-aws-stack \
  --template-body "file://${PWD}/build/aws-stack.json" \
  --capabilities CAPABILITY_IAM \
  --parameters <(cat config.json)
```

Check out [`buildkite-elastic.yml`](templates/buildkite-elastic.yml) for what parameters are available.

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

The best way to get credentials such as Docker Hub login/pass to your builds is to pass them as environmental variables.

For Docker Hub credentials specifically, you can use `DOCKER_HUB_USER`, `DOCKER_HUB_PASSWORD` and `DOCKER_HUB_EMAIL`. The older `DOCKER_HUB_AUTH` with a `dockercfg` format in it is still supported too.
