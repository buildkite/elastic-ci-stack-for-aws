Buildkite Elastic
=================

A generic, auto-scaling group of buildkite instances that are capable of running any project where there is a Dockerfile or a docker-compose.yml present.

This provides a way to run [isolated builds](https://buildkite.com/docs/guides/docker-containerized-builds) across a number of projects on the same servers, allowing large instances and more cost-saving strategies like spot instances to be employed.

Prerequisites
-------------

  * An AWS account with EC2 and CloudFormation
  * [Amazon Commandline Interface](http://aws.amazon.com/cli/) installed and working
  * An S3 bucket with the following files in it:
    * `id_rsa_buildkite` - A github [machine key](https://developer.github.com/guides/managing-deploy-keys/#machine-users) for checking out code
    * `dockercfg` - Authentication details for the docker indexes you will be using

Running
--------

The `create-stack.sh` script will launch the cloudformation stack that powers your buildkite agents.

```bash
create-stack.sh <buildkite org slug> <buildkite agent token> <buildkite api token>
```

For the [api token](https://buildkite.com/user/api-access-tokens) you need one with the `read_projects` permission.

Project Configuration
---------------------

With docker-compose:

```
BUILDKITE_DOCKER_COMPOSE_CONTAINER=app
```

With plain docker:

```
BUILDKITE_DOCKER=true
```

Then you'll need to use the following metadata selection in each of your Buildkite steps:

```
queue=elastic
```