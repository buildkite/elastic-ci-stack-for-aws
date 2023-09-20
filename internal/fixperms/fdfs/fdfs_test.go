//go:build linux

package fdfs

import (
	"io/fs"
	"os"
	"path/filepath"
	"testing"
)

func TestTOCTOUShenanigans(t *testing.T) {
	path := "/tmp/TestTOCTOUShenanigans/foo"
	if err := os.MkdirAll(path, 0o777); err != nil {
		t.Fatalf("os.MkdirAll(%s, %o) = %v", path, 0o777, err)
	}
	fp := filepath.Join(path, "data")
	if err := os.WriteFile(fp, []byte("innocent"), 0o666); err != nil {
		t.Fatalf("os.WriteFile(%s, nil, 0o666) = %v", fp, err)
	}

	path2 := "/tmp/TestTOCTOUShenanigans/crimes"
	if err := os.MkdirAll(path2, 0o777); err != nil {
		t.Fatalf("os.MkdirAll(%s, %o) = %v", path2, 0o777, err)
	}
	fp2 := filepath.Join(path2, "data")
	if err := os.WriteFile(fp2, []byte("guilty"), 0o666); err != nil {
		t.Fatalf("os.WriteFile(%s, nil, 0o666) = %v", fp2, err)
	}

	// Do it in two steps, to simulate a trusted directory and an untrusted
	// subpath.
	fsys, err := DirFS("/tmp/TestTOCTOUShenanigans")
	if err != nil {
		t.Fatalf("DirFS(/tmp/TestTOCTOUShenanigans) error = %v", err)
	}
	defer fsys.Close()
	fooFS, err := fsys.Sub("foo")
	if err != nil {
		t.Fatalf("DirFS(/tmp/TestTOCTOUShenanigans).Sub(foo) error = %v", err)
	}
	defer fooFS.Close()

	// Replace foo with a symlink to crimes...
	path3 := "/tmp/TestTOCTOUShenanigans/foo.bak"
	if err := os.Rename(path, path3); err != nil {
		t.Fatalf("os.Rename(%s, %s) = %v", path, path3, err)
	}
	if err := os.Symlink(path2, path); err != nil {
		t.Fatalf("os.Symlink(%s, %s) = %v", path2, path, err)
	}

	// What do we get?
	df, err := fs.ReadFile(fooFS, "data")
	if err != nil {
		t.Fatalf("fs.ReadFile(DirFS(%s), data) error = %v", path, err)
	}
	if got, want := string(df), "innocent"; got != want {
		t.Fatalf("fs.ReadFile(DirFS(%s), data) contents = %q, want %q", path, got, want)
	}
}
