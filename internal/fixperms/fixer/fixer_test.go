//go:build linux

package fixer

import (
	"fmt"
	"io/fs"
	"os"
	"os/exec"
	"syscall"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestFixer_SlashesErrors(t *testing.T) {
	tests := [][]string{
		{"os.Args[0]", "/", "abc", "abc"},
		{"os.Args[0]", "abc/", "abc", "abc"},
		{"os.Args[0]", "/abc", "abc", "abc"},
		{"os.Args[0]", "abc/def", "abc", "abc"},
		{"os.Args[0]", "abc/def/ghi", "abc", "abc"},
		{"os.Args[0]", "/abc/", "abc", "abc"},
		{"os.Args[0]", "abc", "/", "abc"},
		{"os.Args[0]", "abc", "abc/", "abc"},
		{"os.Args[0]", "abc", "/abc", "abc"},
		{"os.Args[0]", "abc", "abc/def", "abc"},
		{"os.Args[0]", "abc", "abc/def/ghi", "abc"},
		{"os.Args[0]", "abc", "/abc/", "abc"},
		{"os.Args[0]", "abc", "abc", "/"},
		{"os.Args[0]", "abc", "abc", "abc/"},
		{"os.Args[0]", "abc", "abc", "/abc"},
		{"os.Args[0]", "abc", "abc", "abc/def"},
		{"os.Args[0]", "abc", "abc", "abc/def/ghi"},
		{"os.Args[0]", "abc", "abc", "/abc/"},
	}
	for _, test := range tests {
		_, code := Main(test, "/code/internal/fixperms/fixtures", "root")
		if got, want := code, 2; got != want {
			t.Errorf("Main(%v) code = %d, want %d", test, got, want)
		}
	}
}

func TestFixer_DotsErrors(t *testing.T) {
	tests := [][]string{
		{"os.Args[0]", ".", "abc", "abc"},
		{"os.Args[0]", "..", "abc", "abc"},
		{"os.Args[0]", "abc", ".", "abc"},
		{"os.Args[0]", "abc", "..", "abc"},
		{"os.Args[0]", "abc", "abc", "."},
		{"os.Args[0]", "abc", "abc", ".."},
	}
	for _, test := range tests {
		_, code := Main(test, "/code/internal/fixperms/fixtures", "root")
		if got, want := code, 2; got != want {
			t.Errorf("Main(%v) code = %d, want %d", test, got, want)
		}
	}
}

func TestFixer_SymlinksErrors(t *testing.T) {
	tests := [][]string{
		{"os.Args[0]", "link", "b", "c"},
		{"os.Args[0]", "a", "link", "c"},
		{"os.Args[0]", "a", "b", "link"},
	}
	for _, test := range tests {
		_, code := Main(test, "/code/internal/fixperms/fixtures", "root")
		if got, want := code, 3; got != want {
			t.Errorf("Main(%v) code = %d, want %d", test, got, want)
		}
	}
}

func TestFixer_NonDirectoryErrors(t *testing.T) {
	argv := []string{"os.Args[0]", "d", "e", "f"}
	_, code := Main(argv, "/code/internal/fixperms/fixtures", "root")
	if got, want := code, 3; got != want {
		t.Errorf("Main(%v) code = %d, want %d", argv, got, want)
	}
}

func TestFixer_NonExistSkips(t *testing.T) {
	argv := []string{"os.Args[0]", "g", "h", "i"}
	_, code := Main(argv, "/code/internal/fixperms/fixtures", "root")
	if got, want := code, 0; got != want {
		t.Errorf("Main(%v) code = %d, want %d", argv, got, want)
	}
}

func TestFixer_Fixes(t *testing.T) {
	if err := exec.Command("/usr/bin/cp", "-r", "/code/internal/fixperms/fixtures/a", "/tmp").Run(); err != nil {
		t.Fatalf("cp -r fixtures/a /tmp: %v", err)
	}

	argv := []string{"os.Args[0]", "a", "b", "c"}
	_, code := Main(argv, "/tmp", "nobody")
	if got, want := code, 0; got != want {
		t.Errorf("Main(%v) code = %d, want %d", argv, got, want)
	}

	var gotFiles []string
	wantFiles := []string{
		".",
		"d",
		"d/e",
		"d/link",
		"link",
	}

	if err := fs.WalkDir(os.DirFS("/tmp/a/b/c"), ".", func(path string, d fs.DirEntry, err error) error {
		gotFiles = append(gotFiles, path)

		fi, err := d.Info()
		if err != nil {
			return err
		}
		st, ok := fi.Sys().(*syscall.Stat_t)
		if !ok {
			return fmt.Errorf("file info for %s not a *syscall.Stat_t: %T", path, fi.Sys())
		}
		if st.Uid != 65534 {
			t.Errorf("uid of %s = %d, want 65534", path, st.Uid)
		}
		if st.Gid != 65534 {
			t.Errorf("gid of %s = %d, want 65534", path, st.Gid)
		}
		return nil

	}); err != nil {
		t.Errorf("fs.WalkDir(/tmp/a/b/c, .) = %v", err)
	}

	if diff := cmp.Diff(gotFiles, wantFiles); diff != "" {
		t.Errorf("walked files diff (-got +want):\n%s", diff)
	}
}
