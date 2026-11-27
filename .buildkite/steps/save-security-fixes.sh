#!/bin/bash
# Saves this instance's kernel, installed packages, and the CVEs the Amazon Linux
# security advisories for those packages name, with the date, as a build
# artifact. Release builds publish it next to the template, and release notes
# link it (see .buildkite/scripts/ami_security_notes.py). Run it on an instance
# launched from the Amazon Linux 2023 AMI under test.
#
# The file only feeds release notes, so a failure here warns and never fails
# the job.
set -uo pipefail
export LC_ALL=C

os="${1:-linux}"
arch="${2:-amd64}"
fixes="build/security-fixes-${os}-${arch}.txt"

# The AMI's repository is locked to the AMI's release; "latest" has every advisory
# published so far. The time limit keeps a slow repository inside the job's timeout.
# `dnf updateinfo info --json` maps each advisory to its references; the CVEs are
# the ones of type "cve". This prints "cve <CVE> <advisory>" for each.
fixed_cves() {
  timeout 90 dnf --quiet --releasever=latest updateinfo info --installed --security --json \
    | jq -r 'to_entries[] | .key as $advisory | .value.references[]? | select(.Type == "cve") | "cve \(.Id) \($advisory)"' \
    | sort -u -k2,2V -k3,3V
}

header() {
  local today
  today="$(date -u +%F)"
  cat <<EOF
# The kernel, packages and fixed CVEs of this Elastic CI Stack for AWS AMI
# (Amazon Linux 2023, ${arch}), as of ${today}.
#
# A "cve" line is a CVE this AMI has the fix for, and the Amazon Linux advisory
# that names it: https://alas.aws.amazon.com/AL2023/<advisory>.html
# A "package" line is an installed package.
#
# Amazon Linux also publishes advisories after a package has shipped, so a CVE
# missing here is not proof the AMI lacks the fix. Compare the package build on
# https://explore.alas.aws.amazon.com/<CVE>.html with the packages below.

captured ${today}
EOF
}

save_security_fixes() {
  local cves
  mkdir -p build || return
  cves="$(fixed_cves)" || return
  # An empty answer would read as an AMI with no fixes.
  grep -q '^cve ' <<<"$cves" || return
  {
    header \
      && echo "kernel $(uname -r)" \
      && echo \
      && echo "$cves" \
      && echo \
      && rpm -qa --qf 'package %{NAME} %{VERSION}-%{RELEASE}\n' | sort -u
  } >"$fixes" || return
  buildkite-agent artifact upload "$fixes"
}

if save_security_fixes; then
  echo "Saved the security fixes to ${fixes}"
else
  echo "^^^ +++"
  echo "WARNING: could not save the security fixes for ${os}/${arch}; release notes will not list them"
fi
