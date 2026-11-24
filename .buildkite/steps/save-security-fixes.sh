#!/bin/bash
# Saves this instance's kernel and installed packages, and the Amazon Linux
# security advisories those packages include, with the date, as a build
# artifact. Release notes link the published file, and compare two releases'
# files to list the advisories that are new (see
# .buildkite/scripts/ami_security_notes.py). Run it on an instance launched from
# the Amazon Linux 2023 AMI under test.
#
# The file only feeds release notes, so a failure here warns and never fails
# the job.
set -uo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
fixes="build/security-fixes-${os}-${arch}.txt"

# The AMI's repository is locked to the AMI's release; "latest" has every advisory
# published so far. The time limit keeps a slow repository inside the job's timeout.
# Prints an advisory, its severity and the package build it names on each line.
fixed_advisories() {
  timeout 90 dnf --quiet --releasever=latest updateinfo list --installed --security
}

header() {
  local today
  today="$(date -u +%F)"
  cat <<EOF
# The kernel, packages and security advisories of this Elastic CI Stack for AWS
# AMI (Amazon Linux 2023, ${arch}), as of ${today}.
#
# An "advisory" line is an Amazon Linux security advisory this AMI includes the
# fix for: the advisory, its severity, and the package build it names. The AMI
# has that build or a later one. A "package" line is an installed package.
#
# Advisory pages list the CVEs: https://alas.aws.amazon.com/AL2023/<advisory>.html
# To find the advisory for a CVE: https://explore.alas.aws.amazon.com/<CVE>.html
#
# Amazon Linux also publishes advisories after a package has shipped. For one
# that is not listed here, compare the package build on its page with the
# packages below.

captured ${today}
EOF
}

save_security_fixes() {
  local advisories
  mkdir -p build || return
  advisories="$(fixed_advisories)" || return
  # Without advisories, the next release would look like it fixed all of them.
  grep -q '^ALAS' <<<"$advisories" || return
  {
    header \
      && echo "kernel $(uname -r)" \
      && echo \
      && awk '{ sub("/.*", "", $2); print "advisory", $1, $2, $3 }' <<<"$advisories" | LC_ALL=C sort -k2,2V -k4,4 \
      && echo \
      && rpm -qa --qf 'package %{NAME} %{VERSION}-%{RELEASE}\n' | LC_ALL=C sort -u
  } >"$fixes" || return
  buildkite-agent artifact upload "$fixes"
}

if save_security_fixes; then
  echo "Saved the security fixes to ${fixes}"
else
  echo "^^^ +++"
  echo "WARNING: could not save the security fixes for ${os}/${arch}; release notes will not list them"
fi
