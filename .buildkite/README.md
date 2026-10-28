# CI cleanup

The [weekly cleaner](https://buildkite.com/buildkite/elastic-stack-for-aws-ami-cleaner) runs Thursdays at 02:30 UTC. It uses [cleanup.sh](steps/cleanup.sh) to remove old test stacks, secrets buckets, Lambda logs and tagged Packer builders in dist/us-east-1. AMI retention stays the same; base AMIs are untouched.

To preview, start a build on the branch to test with `DRY_RUN=true`, then unblock **Run AMI cleaning build?**. Any set value, including `false` or empty, previews; unset deletes. Check the job logs for candidates.

Apply the cleaner's stack-cleanup permissions before enabling this step.
