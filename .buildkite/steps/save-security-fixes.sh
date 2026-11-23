#!/bin/bash
# Saves the kernel this instance booted, its installed packages, and the Amazon
# Linux advisories and CVEs those packages already fix, as a build artifact. The
# release notes compare two releases' files to list what a release newly fixes
# (see .buildkite/scripts/ami_security_notes.py). Run it on an instance launched
# from the Amazon Linux 2023 AMI under test.
#
# The file only feeds release notes, so a failure here warns and never fails
# the job.
set -uo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
fixes="build/security-fixes-${os}-${arch}.txt"

# The AMI's repository is locked to the AMI's release; "latest" has every advisory
# published so far. The time limit keeps a slow repository inside the job's timeout.
fixed_advisories() {
  timeout 90 dnf --quiet --releasever=latest updateinfo list --installed --security "$@"
}

save_security_fixes() {
  mkdir -p build || return
  {
    echo "kernel $(uname -r)" \
      && rpm -qa --qf 'package %{NAME} %{VERSION}-%{RELEASE}\n' | LC_ALL=C sort -u \
      && fixed_advisories \
      && fixed_advisories --with-cve
  } >"$fixes" || return
  # Without advisories, the next release would look like it fixed all of them.
  grep -q '^ALAS' "$fixes" || return
  # Over 1 MB of text per AMI, and under 100 KB compressed.
  gzip -9 --force "$fixes" || return
  buildkite-agent artifact upload "${fixes}.gz"
}

if save_security_fixes; then
  echo "Saved the security fixes to ${fixes}.gz"
else
  echo "^^^ +++"
  echo "WARNING: could not save the security fixes for ${os}/${arch}; release notes will not list them"
fi
