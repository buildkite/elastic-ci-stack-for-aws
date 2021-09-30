# Releasing the Elastic CI Stack for AWS

A super quick rundown of the steps to release the AWS Elastic Stack:

1. Generate a changelog to preview the changes `ghch --format=markdown --from=v5.3.0 --next-version=v5.4.0` and decide whether this is a major, minor, or bugfix
release. Re-run `ghch` if necessary to change the next version.
1. Create a branch to update the changelog e.g. `keithduncan/release/v5.4.0`
1. Update `CHANGELOG.md`, rearrange it into whatever categories makes sense,
usually Added, Changed, Fixed, Removed
	1. Commit the changelog (don’t use [skip CI] in the commit message, that will prevent the tag from kicking off a build)
	1. Push the branch
1. While waiting for the branch to build, test and deploy...
1. Draft a release in GitHub
	1. Fill in the release version as a git tag, use the release branch as a tag target
	1. Set the release title to the the release version
	1. Add upgrade instructions to the end of the GitHub release (copied and updated from the previous one)
	1. Save the release as a draft (doesn't create the tag until the release is published)
1. Once the branch build has passed, deploy the stack and perform manual of
changed aspects. Once you are satisfied the changes are good and there aren't any
regressions, publish the draft GitHub release to create the tag and kick off the tag build process.
1. Merge the release branch to the repository’s default branch
1. Update buildkite/docs with the versions of installed software

## Announcements

Draft a Buildkite Changelog using the following template:

> Title: Agent vx.x.x and AWS Elastic Stack vx.x.x release
> Content:
> The x.x.x version of the buildkite-agent and the x.x.x version of the AWS elastic stack are now available.
> 
> The agent has added the ability to do ____, and ____. This agent release has been added to the x.x.x release of the elastic stack, as well as ____ and ____. 
> 
> For full list of additions, changes, and fixes, see the [buildkite-agent changelog](https://github.com/buildkite/agent/releases/tag/v3.31.0) and the [elastic-ci-stack-for-aws changelog](https://github.com/buildkite/elastic-ci-stack-for-aws/releases/tag/v5.4.0) on GitHub.

Publish a 🚀 Release category message in the [🤖 Agent Message Board](https://3.basecamp.com/3453178/buckets/11763568/message_boards/1730831248).

Notify the Buildkite Community #aws-stack Slack channel of the new release.
