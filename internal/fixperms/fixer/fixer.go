//go:buid linux

package fixer

import (
	"errors"
	"fmt"
	"io/fs"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/buildkite/elastic-ci-stack-for-aws/v5/internal/fixperms/fdfs"
)

// Main contains the higher-level operations of the permissions fixer.
func Main(argv []string, baseDir, uname string) (string, int) {
	if len(argv) != 4 {
		return exitf(1, "Usage: %s AGENT_DIR ORG_DIR PIPELINE_DIR", argv[0])
	}
	for _, seg := range argv[1:] {
		if seg != filepath.Clean(seg) {
			return exitf(2, "Invalid argument %q", seg)
		}
		if seg == "." || seg == ".." || strings.ContainsRune(seg, '/') {
			return exitf(2, "Invalid argument %q", seg)
		}
	}
	subpath := filepath.Join(argv[1:]...)

	// Get a file descriptor for the base builds directory.
	bd, err := fdfs.DirFS(baseDir)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return exit0()
		}
		return exitf(3, "Couldn't open %s: %v", baseDir, err)
	}
	defer bd.Close()

	// Get a file descriptor for the agentdir/orgdir/pipelinedir within the
	// builds directory.
	// openat2(2) flags ensures this is within the builds directory, and does
	// not involve a symlink.
	pd, err := bd.Sub(subpath)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return exit0()
		}
		return exitf(3, "Couldn't open %s: %v", subpath, err)
	}
	defer pd.Close()

	// Get the uid and gid of buildkite-agent
	agentUser, err := user.Lookup(uname)
	if err != nil {
		return exitf(4, "Couldn't look up buildkite-agent user: %v", err)
	}
	uid, err := strconv.Atoi(agentUser.Uid)
	if err != nil {
		return exitf(4, "buildkite-agent uid %q not an integer: %v", agentUser.Uid, err)
	}
	gid, err := strconv.Atoi(agentUser.Gid)
	if err != nil {
		return exitf(4, "buildkite-agent gid %q not an integer: %v", agentUser.Gid, err)
	}

	// Do the recursive chown.
	if err := pd.RecursiveChown(uid, gid); err != nil {
		return exitf(5, "Couldn't recursively chown %s: %v", subpath, err)
	}
	return exit0()
}

func exit0() (string, int) { return "", 0 }

func exitf(code int, f string, v ...any) (string, int) {
	return fmt.Sprintf(f, v...), code
}
