//go:build linux

// The fixperms tool changes the ownership of certain files to buildkite-agent.
package main

import (
	"fmt"
	"os"

	"github.com/buildkite/elastic-ci-stack-for-aws/v5/internal/fixperms/fixer"
)

// Files that are created by Docker containers end up with strange user and
// group ids, usually 0 (root). Docker namespacing will one day save us, but it
// can only map a single docker user id to a given user id (not any docker user
// id to a single system user id).
//
// Until we can map any old user id back to buildkite-agent automatically with
// Docker, then we just need to fix the permissions manually before each build
// runs so git clean can work as expected.
//
// In order to fix ownership of files owned by root, we need to be root. Thus,
// buildkite-agent has rights to run this program with sudo (see sudoers.conf).
// That means we have to take extra care to not chown things we shouldn't.
//
// Q1: Why not `chown -Rh /var/lib/buildkite-agents/builds`?
// A1: That gets slower as more and more builds are run on this agent, hence the
//     args that specify a particular pipeline dir. See #340.
//
// Q2: Why not a small script that checks the args for shenanigans, then runs
//     `chown -Rh ...`?
// A2: Because of TOCTOU. There's a race between checking that there are no
//     symlink shenanigans, and calling `chown`, which provides time for an
//     attacker to put some shenanigans back in before `chown` is called.
//
// Q3: What about running `chown -Rh` in a chroot that also contains the dir?
// A3: You have to copy the tools you need to run into the chroot. A job could
//     overwrite the tool with its own binary, which is then run as root.
//     And if you think you can carefully lay out the chroot and set permissions
//     to prevent that, you still need to stop the script receiving a symlink to
//     the directory containing chown, changing its own perms. If you add a
//     check for that first, then there's still TOCTOU.
//
// Q4: Containers!
// A4: *sigh*
//
// File paths are not a good security interface for files. But! We can use file
// descriptors. openat(2), fchownat(2), etc provide a way to resolve file paths
// relative to a given parent directory, and prevent symlink resolution at the
// same time.

const (
	buildsDir = "/var/lib/buildkite-agent/builds"
	username  = "buildkite-agent"
)

func main() {
	msg, code := fixer.Main(os.Args, buildsDir, username)
	if code != 0 {
		fmt.Fprintln(os.Stderr, msg)
		os.Exit(code)
	}
}
