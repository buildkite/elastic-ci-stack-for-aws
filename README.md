Buildkite Elastic
=================

A set of AWS scripts for creating an auto-scaling cloud of Buildkite workers for
building Docker based projects.

Installing
----------

This assumes you have `awscli` installed and configured, and your Buildkite token
in a `$BUILDKITE_TOKEN` env variable.

```bash
scripts/create-stack.sh $BUILDKITE_TOKEN
```

This will light up the cloud infrastructure. Now you can configure your projects.

Architecture
------------

A CloudFormation template is provided that provisions a metrics instance and an autoscale
group of agents. The metrics instance runs the [Buildkite metrics publisher](https://github.com/buildkite/buildkite-cloudwatch-metrics-publisher) to update queue length into Cloudwatch. This metric is used to autoscale the agent group.

Development
-----------

The `buildkite-cloudformation.yml` file is the canonical source, it uses cfoo to generate
the json output.


