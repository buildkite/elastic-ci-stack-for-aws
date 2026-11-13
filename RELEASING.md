# Releasing

Pushing a `vX.Y.Z` tag starts the release build. It builds and tests every AMI,
copies them to all regions, and publishes the CloudFormation templates to
`https://s3.amazonaws.com/buildkite-aws-stack/<tag>/`. The newest stable tag on
`main` also updates `latest/`. Nothing holds back AWS publication after the tag
is pushed, so check the version and target before tagging.

- v7 releases come from `main`.
- v6 releases come from `v6` and carry security fixes only.

## 1. Choose the version and target

```bash
git fetch origin --tags
branch=main # or v6
previous=$(git describe --tags --abbrev=0 --match 'v7.*' --exclude '*-*' "origin/$branch") # or 'v6.*'
target=$(git rev-parse "origin/$branch")
git log --oneline "$previous..$target"
gh pr list --base "$branch" --label buildkite-agent
```

Check open PRs into the branch, especially Renovate Agent updates, and merge any
the release should include before choosing the target. Use a patch version for
fixes and a minor version for features or a minor Agent update.

## 2. Push the tag

```bash
tag=v7.X.Y
git tag -a "$tag" "$target" -m "$tag"
git push origin "refs/tags/$tag"
```

Never move or delete a pushed tag. To change what a release contains, cut the
next patch version.

The release build appears in the
[pipeline](https://buildkite.com/buildkite-aws-stack/buildkite-aws-stack) with
its branch set to the tag, and takes about 30 minutes. A `main` build for the
same commit is not the release build. Its publish step checks that the
versioned templates are public and match what the build produced.

## 3. Prepare the notes while it builds

Work from `main`, including for v6 releases: the scripts read everything from
the tags.

```bash
git switch -c "release/$tag" origin/main
.buildkite/scripts/generate-changelog.sh "$tag" "$previous"
```

Edit the new `CHANGELOG.md` entry:

- Sort entries into Added, Changed, Fixed, Removed, Security, and Internal.
- Write short, plain bullets with no trailing periods. Keep PR links and authors.
- Leave out changelog-only PRs.
- Keep the Agent changelog section as generated.

Then create a draft release from the entry and the upgrade instructions for
its release line:

```bash
.buildkite/scripts/release-notes.sh "$tag" \
  | gh release create "$tag" --verify-tag --draft --latest=false \
    --title "$tag" --notes-file -
```

Rerun `release-notes.sh` and `gh release edit "$tag" --notes-file -` after any
later edit, so both texts stay the same.

## 4. Publish after the build passes

Retry flaky jobs in the same build. If the release needs a code fix, merge it
and cut a new patch version.

Once the build passes, open the changelog PR:

```bash
git commit -m "Add release notes for $tag" -- CHANGELOG.md
git push -u origin "release/$tag"
gh pr create --base main --title "Update changelog for $tag" \
  --label release-notes --body ""
```

Then publish the draft. Only v7 releases are Latest:

```bash
gh release edit "$tag" --draft=false --latest=true  # v7
gh release edit "$tag" --draft=false --latest=false # v6
```

In the GitHub UI, untick **Set as latest release** when publishing v6.

Never overwrite the S3 `latest/` templates by hand.
