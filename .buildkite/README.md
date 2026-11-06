# CI cleanup

The [cleanup pipeline](https://buildkite.com/buildkite/elastic-stack-for-aws-ami-cleaner) uses `CLEANUP_SCOPE=resources` for daily test-resource cleanup (01:30 UTC) and `CLEANUP_SCOPE=amis` for weekly AMI cleanup (Thursday 02:30 UTC). Each build runs only its selected scope.

Resource cleanup uses [cleanup.sh](steps/cleanup.sh) to remove old test stacks, secrets buckets, Lambda logs and tagged Packer builders in dist/us-east-1. Resource-age cutoffs, AMI retention and normal build cleanup stay unchanged; base AMIs are untouched.

To preview, start a build on the branch to test with `CLEANUP_SCOPE=resources` or `CLEANUP_SCOPE=amis` and `DRY_RUN=true`, then unblock **Run AMI cleaning build?**. Any set `DRY_RUN` value, including `false` or empty, previews; unset deletes. Check the job logs for candidates.

Apply stack-cleanup and CI role-tagging permissions before enabling this step. Stack and execution-role deletions require `ManagedBy=elastic-ci-stack-for-aws` and `Purpose=disposable-ci`.
