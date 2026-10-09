# CI cleanup

The [AMI cleaner](https://buildkite.com/buildkite/elastic-stack-for-aws-ami-cleaner) runs every Thursday at 02:30 UTC. It removes old stack AMIs under existing retention rules and [tagged Packer builders](steps/cleanup-packer.sh) older than 24 hours in dist/us-east-1. Base AMIs are untouched. Normal builds run the same builder sweep; weekly cleanup catches leftovers.

For a manual run, select **New Build** on `main`, then unblock **Run AMI cleaning build?**. Set `DRY_RUN=true` to preview both cleaners; leave it unset to delete, as scheduled runs do. Any set value, including `false` or empty, means preview. Check job logs for candidates.

`DRY_RUN` does **not** make the rest of normal-build `cleanup.sh` read-only.
