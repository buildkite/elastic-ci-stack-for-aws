#!/bin/bash
# Runs generate-changelog.sh and release-notes.sh in a scratch repository with a
# stub gh on PATH. Needs only bash, git and coreutils.
set -euo pipefail

scripts=$(cd "$(dirname "$0")" && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/repo/packer/linux/stack/scripts"

# Model GitHub's generated notes, and more Agent releases than one page of 100.
cat >"$fixture/bin/gh" <<'GH'
#!/bin/bash
set -euo pipefail
case "$*" in
  'api --method POST '*)
    printf '%s\r\n' \
      '<!-- Release notes generated using configuration in .github/release.yml at main -->' \
      '' \
      "## What's Changed" \
      '### Fixed' \
      '* Fix a stack bug by @someone in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/12' \
      '### Other changes' \
      '* Update a tool by @renovate[bot] in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/13' \
      '' \
      '## New Contributors' \
      '* @someone made their first contribution in https://github.com/buildkite/elastic-ci-stack-for-aws/pull/12' \
      '' \
      '**Full Changelog**: https://github.com/buildkite/elastic-ci-stack-for-aws/compare/v7.0.0...v7.1.0'
    ;;
  'api --paginate repos/buildkite/agent/releases?per_page=100 '*)
    for version in $(seq 205 -1 1); do
      [[ "3.$version.0" != "${OMIT_AGENT:-}" ]] || continue
      printf 'v3.%s.0\n' "$version"
    done
    ;;
  'release view '*) printf '### Agent changes\nNotes for %s, including C:\\agent\n' "$3" ;;
  *)
    echo "Unexpected gh command: $*" >&2
    exit 1
    ;;
esac
GH
chmod +x "$fixture/bin/gh"
export PATH="$fixture/bin:$PATH"

cd "$fixture/repo"
git init -q
git config user.name 'Changelog test'
git config user.email 'changelog-test@example.invalid'
git config commit.gpgsign false
git config tag.gpgsign false
printf '%s\n' '# Changelog' '' 'Intro' '' '<!-- releases -->' '' \
  '## [v7.0.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v7.0.0) (2026-01-01)' \
  'Old content' >CHANGELOG.md
printf 'AGENT_VERSION="3.1.0"\n' >packer/linux/stack/scripts/install-buildkite-agent.sh
git add .
git commit -qm 'Previous release'
git tag -a v7.0.0 -m v7.0.0
printf 'AGENT_VERSION="3.205.0"\n' >packer/linux/stack/scripts/install-buildkite-agent.sh
git add .
# The release commit is older than its tag; the entry must use the tag's date.
GIT_COMMITTER_DATE='2026-03-01T12:00:00Z' git commit -qm 'Current release'
GIT_COMMITTER_DATE='2026-03-09T12:00:00Z' git tag -a v7.1.0 -m v7.1.0
cp CHANGELOG.md "$fixture/original.md"

bash "$scripts/generate-changelog.sh" v7.1.0 v7.0.0 >"$fixture/output.log" 2>&1
grep -Fqx '## [v7.1.0](https://github.com/buildkite/elastic-ci-stack-for-aws/tree/v7.1.0) (2026-03-09)' CHANGELOG.md
grep -Fqx '### Fixed' CHANGELOG.md
grep -Fqx -- '- Fix a stack bug [#12](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/12) (@someone)' CHANGELOG.md
grep -Fqx -- '- Update a tool [#13](https://github.com/buildkite/elastic-ci-stack-for-aws/pull/13) (@renovate[bot])' CHANGELOG.md
if grep -Eq "What.s Changed|New Contributors|first contribution|\*\*Full Changelog|Release notes generated|"$'\r' CHANGELOG.md; then
  echo 'GitHub boilerplate left in CHANGELOG.md' >&2
  exit 1
fi
echo 'PASS: generated notes use changelog bullets, the tag date, and no GitHub boilerplate'

[[ $(grep -c '^### \[v3\.' CHANGELOG.md) -eq 204 ]]
[[ $(grep '^### \[v3\.' CHANGELOG.md | head -n 1) == '### [v3.205.0]'* ]]
[[ $(grep '^### \[v3\.' CHANGELOG.md | tail -n 1) == '### [v3.2.0]'* ]]
grep -Fq 'C:\agent' CHANGELOG.md
grep -q '^Old content$' CHANGELOG.md
echo 'PASS: complete Agent range beyond 200 releases, newest first, preserving notes and existing content'

bash "$scripts/release-notes.sh" v7.1.0 >"$fixture/notes.md"
grep -Fq 'Fix a stack bug' "$fixture/notes.md"
grep -Fq 'v7 upgrade guide' "$fixture/notes.md"
grep -Fq 'templateURL=https://s3.amazonaws.com/buildkite-aws-stack/v7.1.0/aws-stack.yml' "$fixture/notes.md"
if grep -q 'Old content' "$fixture/notes.md"; then
  echo 'Release body includes an older entry' >&2
  exit 1
fi
echo 'PASS: release body is only this entry plus v7 upgrade instructions'

for missing in 3.1.0 3.205.0; do
  cp "$fixture/original.md" CHANGELOG.md
  if OMIT_AGENT="$missing" bash "$scripts/generate-changelog.sh" v7.1.0 v7.0.0 >"$fixture/output.log" 2>&1; then
    echo "Expected rejection for missing Agent release $missing" >&2
    exit 1
  fi
  grep -q 'Cannot enumerate the complete Agent release range' "$fixture/output.log"
  cmp "$fixture/original.md" CHANGELOG.md
done
echo 'PASS: missing range endpoints fail without changing the changelog'
