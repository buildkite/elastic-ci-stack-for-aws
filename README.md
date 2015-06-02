Buildkite Elastic
=================

A set of AWS scripts for creating an auto-scaling cloud of Buildkite workers for
building Docker based projects.

Prerequisites
-------------

  * [Amazon Commandline Interface](http://aws.amazon.com/cli/) installed and working
  * An S3 bucket with the following files in it:
    * `id_rsa_buildkite` - A github [machine key](https://developer.github.com/guides/managing-deploy-keys/#machine-users) for checking out code
    * `dockercfg` - Authentication details for docker indexes you will be using

Running
--------

The `create-stack.sh` script will launch the cloudformation stack that powers your buildkite agents.

```bash
create-stack.sh <buildkite org slug> <buildkite agent token> <buildkite api token>
```

For the [api token](https://buildkite.com/user/api-access-tokens) you need one with the `read_projects` permission.
