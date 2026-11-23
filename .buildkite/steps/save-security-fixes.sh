#!/bin/bash
# Saves the CVEs Amazon Linux has published fixes for in this instance's
# packages, with the date, the kernel it booted and its installed packages, as a
# build artifact. Release notes link the published file, and compare two
# releases' files to list the fixes that are new (see
# .buildkite/scripts/ami_security_notes.py). Run it on an instance launched from
# the Amazon Linux 2023 AMI under test.
#
# The file only feeds release notes, so a failure here warns and never fails
# the job.
set -uo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
fixes="build/security-fixes-${os}-${arch}.txt"

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# The AMI's repository is locked to the AMI's release; "latest" has every advisory
# published so far. The time limit keeps a slow repository inside the job's timeout.
fixed_advisories() {
  timeout 90 dnf --quiet --releasever=latest updateinfo list --installed --security "$@"
}

# dnf lists advisories and CVEs separately, each with the package build that
# carries the fix. This puts each CVE beside the advisories for its build, oldest
# CVE first and advisories without a CVE last.
fixes_by_cve() {
  # The first column only orders the two kinds of line, and is cut after sorting.
  awk '
    FNR == NR { advisories[$3] = advisories[$3] comma[$3] $1; comma[$3] = ","; severity[$3] = $2; next }
    { has_cve[$3] = 1; sub("/.*", "", $2); print 0, $1, advisories[$3], $2, $3 }
    END {
      for (build in advisories) {
        if (build in has_cve) continue
        sub("/.*", "", severity[build])
        print 1, "-", advisories[build], severity[build], build
      }
    }
  ' "$scratch/advisories" "$scratch/cves" | LC_ALL=C sort -k1,1n -k2,2V -k5,5 | cut -d' ' -f2-
}

header() {
  local today
  today="$(date -u +%F)"
  cat <<EOF
# Security fixes in the Amazon Linux packages of this Elastic CI Stack for AWS
# AMI (Amazon Linux 2023, ${arch}), as Amazon Linux had published them on ${today}.
#
# After the date and the booted kernel, each line is a fixed CVE: the CVE, the
# Amazon Linux advisories for the package build that fixed it, the severity, and
# the package build Amazon Linux names for the fix. The AMI has that build or a
# later one. A "-" in place of the CVE is an advisory that names no CVE.
#
# Amazon Linux also publishes advisories, and adds CVEs to them, after a package
# has shipped, so the AMI can include fixes this file does not list. For a CVE
# that is not here, compare the fixed version at
# https://explore.alas.aws.amazon.com/<CVE>.html with the installed packages at
# the end of this file.
#
# Advisory pages: https://alas.aws.amazon.com/AL2023/<advisory>.html

captured ${today}
EOF
}

save_security_fixes() {
  mkdir -p build || return
  fixed_advisories >"$scratch/advisories" || return
  fixed_advisories --with-cve >"$scratch/cves" || return
  # Without advisories, the next release would look like it fixed all of them.
  grep -q '^ALAS' "$scratch/advisories" || return
  {
    header \
      && echo "kernel $(uname -r)" \
      && echo \
      && fixes_by_cve \
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
