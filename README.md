# Buildkite AWS Stack

Provides a s[CloudFormation][] template for launching a cluster of generic Buildkite agents that will scale based on the work volume they are processing.

This stack is designed for generic use as a "build cloud" for an organization which can serve many different projects with a single stack. Because of this, tricks like [auto-scaling][] and [spot instances][] can keep costs low whilst providing build infrastructure to even the smallest projects.

## Status

Experimental. Still being actively developed, but under heavy use at 99designs.

Join the `#aws` channel in [Buildkite Slack](https://chat.buildkite.com/) and ask me (@lox) questions if they arise.


## Prerequisites

 - A configured AWS account with CloudFormation access
 - [Amazon Commandline Interface](http://aws.amazon.com/cli/) configured and credentials available

## Installation

Configuration for the stack is provided in `config.json`, rename and edit [`config.json.sample`](config.json.sample) and then launch the stack.

```
cp config.json.sample config.json
make create-stack
```

## Getting Started

By default your stack is using a Buildkite queue of `elastic`. If you target any Buildkite projects to use this queue then builds will be run on your instances.

