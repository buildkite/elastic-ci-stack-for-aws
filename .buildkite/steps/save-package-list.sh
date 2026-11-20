#!/bin/bash
# Saves the packages installed on this instance as a build artifact, so the
# release notes can list the security fixes an AMI picked up since the last
# release (see .buildkite/scripts/ami_security_notes.py). Run it on an instance
# launched from the AMI under test.
#
# The list only feeds release notes, so a failure here warns and never fails
# the job.
set -uo pipefail

os="${1:-linux}"
arch="${2:-amd64}"
package_list="build/packages-${os}-${arch}.tsv"

save_package_list() {
  mkdir -p build || return
  # One row per installed RPM: name, epoch, version, release, architecture.
  rpm -qa --qf '%{NAME}\t%{EPOCHNUM}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' | LC_ALL=C sort >"$package_list" || return
  buildkite-agent artifact upload "$package_list"
}

if save_package_list; then
  echo "Saved $(wc -l <"$package_list") packages to ${package_list}"
else
  echo "^^^ +++"
  echo "WARNING: could not save the package list for ${os}/${arch}; release notes will not list its security fixes"
fi
