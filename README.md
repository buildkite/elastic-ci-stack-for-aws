Buildkite Elastic
=================

A set of AWS scripts for creating an auto-scaling cloud of Buildkite workers for
building Docker based projects.

Installing
----------

This assumes you have `awscli` installed and configured, `brew install awscli` will do the trick on OSX.

First you will need an s3 bucket (by default `<orgslug>-buildkite`), with an ssh key called `id_rsa_buildkite` in it that can be used to checkout projects. See the docs on [machine users on github](https://developer.github.com/guides/managing-deploy-keys/#machine-users) for more details.

```bash
create-stack.sh <buildkite org slug> <buildkite agent token> <buildkite api token>
```

For the [api token](https://buildkite.com/user/api-access-tokens) you need one with the `read_projects` permission.

This will light up the cloud infrastructure. Now you can configure your projects.

Architecture
------------

A CloudFormation template is provided that provisions a metrics instance and an autoscale
group of agents. The metrics instance runs the [Buildkite metrics publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) to update queue length into Cloudwatch. This metric is used to autoscale the agent group.


