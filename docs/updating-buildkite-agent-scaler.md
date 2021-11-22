# Updating buildkite-agent-scaler

The [buildkite-agent-scaler](https://buildkite.com/buildkite/buildkite-agent-scaler)
is brought in to the Elastic CI Stack for AWS template using the AWS
Serverless Application Repository.

Once you have [released](https://github.com/buildkite/buildkite-agent-scaler/blob/master/RELEASE.md)
an updated version, you can incorporate it into the Elastic CI Stack for AWS
template.

See https://github.com/buildkite/elastic-ci-stack-for-aws/pull/955 for an
example of updating the buildkite-agent-scaler.

1. Create a new branch
1. In the [`templates/aws-stack.yml`](templates/aws-stack.yml) update the `Autoscaling` resource’s `SemanticVersion` property to the newly released version.
1. Push your branch and open a pull request
1. Wait for CI to pass
1. If needed for testing, create a stack with the branch’s published template to verify functionality
	1. In the Buildkite build, get the template URL from the build annotation
	1. In the AWS Console, launch CloudFormation
	1. Create a new stack, select new resources
	1. Supply the template URL from the build annotation for the Amazon S3 URL field
	1. Supply a Buildkite Agent token in the `BuildkiteAgentToken` 
	or `BuildkiteAgentTokenParameterStorePath` parameters
	1. Supply a queue in the `BuildkiteQueue` parameter
	1. Create the stack and wait for it to complete
	1. Verify that instances are booted in response to Buildkite jobs on your queue
	1. Delete the stack
1. Merge your pull request
