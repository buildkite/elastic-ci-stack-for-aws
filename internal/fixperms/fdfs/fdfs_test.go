//go:build linux

package fdfs

import (
	"context"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"

	"golang.org/x/sync/errgroup"
)

func TestTOCTOUShenanigans(t *testing.T) {
	base := t.TempDir()
	path := filepath.Join(base, "foo")
	if err := os.MkdirAll(path, 0o777); err != nil {
		t.Fatalf("os.MkdirAll(%s, %o) = %v", path, 0o777, err)
	}
	fp := filepath.Join(path, "data")
	if err := os.WriteFile(fp, []byte("innocent"), 0o666); err != nil {
		t.Fatalf("os.WriteFile(%s, nil, 0o666) = %v", fp, err)
	}

	path2 := filepath.Join(base, "crimes")
	if err := os.MkdirAll(path2, 0o777); err != nil {
		t.Fatalf("os.MkdirAll(%s, %o) = %v", path2, 0o777, err)
	}
	fp2 := filepath.Join(path2, "data")
	if err := os.WriteFile(fp2, []byte("guilty"), 0o666); err != nil {
		t.Fatalf("os.WriteFile(%s, nil, 0o666) = %v", fp2, err)
	}

	// Do it in two steps, to simulate a trusted directory and an untrusted
	// subpath.
	fsys, err := DirFS(base)
	if err != nil {
		t.Fatalf("DirFS(%s) error = %v", base, err)
	}
	defer fsys.Close()
	fooFS, err := fsys.Sub("foo")
	if err != nil {
		t.Fatalf("DirFS(%s).Sub(foo) error = %v", base, err)
	}
	defer fooFS.Close()

	// Replace foo with a symlink to crimes...
	path3 := filepath.Join(base, "foo.bak")
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

// TestRecursiveChown_TreeShapes walks shapes that exercise both the
// spawn-a-worker and fall-back-to-inline branches of dispatch, and
// checks counter accuracy. Chown is a no-op (uid matches), so no root.
func TestRecursiveChown_TreeShapes(t *testing.T) {
	tests := []struct {
		name  string
		build func(t *testing.T, dir string) (wantFiles, wantDirs int)
	}{
		{
			// Forces sem saturation and inline fallback.
			name: "wide_shallow",
			build: func(t *testing.T, dir string) (int, int) {
				const n = 100
				for i := 0; i < n; i++ {
					sub := filepath.Join(dir, fmt.Sprintf("s%d", i))
					mkdir(t, sub)
					writeFile(t, filepath.Join(sub, "f"))
				}
				return n, n + 1
			},
		},
		{
			// Drives the inline recursion path.
			name: "deep_narrow",
			build: func(t *testing.T, dir string) (int, int) {
				const n = 100
				p := dir
				for i := 0; i < n; i++ {
					p = filepath.Join(p, "d")
					mkdir(t, p)
				}
				writeFile(t, filepath.Join(p, "leaf"))
				return 1, n + 1
			},
		},
		{
			name: "mixed",
			build: func(t *testing.T, dir string) (int, int) {
				const a, b, f = 20, 5, 5
				for i := 0; i < a; i++ {
					ad := filepath.Join(dir, fmt.Sprintf("a%d", i))
					mkdir(t, ad)
					for j := 0; j < b; j++ {
						bd := filepath.Join(ad, fmt.Sprintf("b%d", j))
						mkdir(t, bd)
						for k := 0; k < f; k++ {
							writeFile(t, filepath.Join(bd, fmt.Sprintf("f%d", k)))
						}
					}
				}
				return a * b * f, 1 + a + a*b
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			dir := t.TempDir()
			wantFiles, wantDirs := tt.build(t, dir)

			fsys, err := DirFS(dir)
			if err != nil {
				t.Fatalf("DirFS(%s): %v", dir, err)
			}
			defer fsys.Close()

			// Drive walkContents directly to read counters.
			g, ctx := errgroup.WithContext(context.Background())
			g.SetLimit(min(128, max(1, 2*4)))

			var files, dirs atomic.Uint64
			if err := walkContents(ctx, g, fsys, os.Getuid(), os.Getgid(), &files, &dirs); err != nil {
				t.Fatalf("walkContents: %v", err)
			}
			if err := g.Wait(); err != nil {
				t.Fatalf("g.Wait: %v", err)
			}

			if got := files.Load(); got != uint64(wantFiles) {
				t.Errorf("files = %d, want %d", got, wantFiles)
			}
			if got := dirs.Load(); got != uint64(wantDirs) {
				t.Errorf("dirs = %d, want %d", got, wantDirs)
			}
		})
	}
}

// TestRecursiveChown_Symlinks checks that symlinks (to files or dirs) are
// chowned as non-dir entries and never recursed into.
func TestRecursiveChown_Symlinks(t *testing.T) {
	dir := t.TempDir()

	writeFile(t, filepath.Join(dir, "real_file"))
	if err := os.Symlink("real_file", filepath.Join(dir, "link_to_file")); err != nil {
		t.Fatal(err)
	}

	mkdir(t, filepath.Join(dir, "subdir"))
	writeFile(t, filepath.Join(dir, "subdir", "f"))
	if err := os.Symlink("subdir", filepath.Join(dir, "link_to_dir")); err != nil {
		t.Fatal(err)
	}

	fsys, err := DirFS(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer fsys.Close()

	g, ctx := errgroup.WithContext(context.Background())
	g.SetLimit(4)
	var files, dirs atomic.Uint64
	if err := walkContents(ctx, g, fsys, os.Getuid(), os.Getgid(), &files, &dirs); err != nil {
		t.Fatalf("walkContents: %v", err)
	}
	if err := g.Wait(); err != nil {
		t.Fatalf("g.Wait: %v", err)
	}

	// dirs: root + subdir. link_to_dir must not be recursed.
	if got, want := dirs.Load(), uint64(2); got != want {
		t.Errorf("dirs = %d, want %d", got, want)
	}
	// files: real_file + link_to_file + link_to_dir + subdir/f.
	if got, want := files.Load(), uint64(4); got != want {
		t.Errorf("files = %d, want %d", got, want)
	}
}

// TestRecursiveChown_ActualLchown exercises real Lchown by chowning to
// nobody under root. The no-op tests above take the fast-path skip.
func TestRecursiveChown_ActualLchown(t *testing.T) {
	if os.Geteuid() != 0 {
		t.Skip("requires root to chown to a different uid/gid")
	}

	const nobodyUID, nobodyGID = 65534, 65534
	dir := t.TempDir()

	writeFile(t, filepath.Join(dir, "f1"))
	mkdir(t, filepath.Join(dir, "sub"))
	writeFile(t, filepath.Join(dir, "sub", "f2"))
	if err := os.Symlink("f1", filepath.Join(dir, "link_to_f1")); err != nil {
		t.Fatal(err)
	}

	fsys, err := DirFS(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer fsys.Close()

	if err := fsys.RecursiveChown(nobodyUID, nobodyGID); err != nil {
		t.Fatalf("RecursiveChown: %v", err)
	}

	err = filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		info, err := d.Info()
		if err != nil {
			return err
		}
		st, ok := info.Sys().(*syscall.Stat_t)
		if !ok {
			return fmt.Errorf("stat for %s is not *syscall.Stat_t", path)
		}
		if st.Uid != nobodyUID {
			t.Errorf("%s uid = %d, want %d", path, st.Uid, nobodyUID)
		}
		if st.Gid != nobodyGID {
			t.Errorf("%s gid = %d, want %d", path, st.Gid, nobodyGID)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("verification walk: %v", err)
	}
}

// TestRecursiveChown_PublicAPI smoke-tests the public API. Lchown is not
// exercised (same-uid fast-path); TestRecursiveChown_ActualLchown covers it.
func TestRecursiveChown_PublicAPI(t *testing.T) {
	dir := t.TempDir()
	for i := 0; i < 10; i++ {
		sub := filepath.Join(dir, fmt.Sprintf("s%d", i))
		mkdir(t, sub)
		writeFile(t, filepath.Join(sub, "f"))
	}

	fsys, err := DirFS(dir)
	if err != nil {
		t.Fatalf("DirFS: %v", err)
	}
	defer fsys.Close()

	if err := fsys.RecursiveChown(os.Getuid(), os.Getgid()); err != nil {
		t.Fatalf("RecursiveChown: %v", err)
	}
}

// TestRecursiveChown_TOCTOUConcurrent: attacker swaps subdirs for
// symlinks to a honeypot outside the tree while RecursiveChown runs.
// Honeypot ownership must stay unchanged.
func TestRecursiveChown_TOCTOUConcurrent(t *testing.T) {
	if os.Geteuid() != 0 {
		t.Skip("requires root to chown to a different uid/gid")
	}

	base := t.TempDir()
	const n = 50
	for i := 0; i < n; i++ {
		sub := filepath.Join(base, fmt.Sprintf("s%d", i))
		mkdir(t, sub)
		for j := 0; j < 5; j++ {
			writeFile(t, filepath.Join(sub, fmt.Sprintf("f%d", j)))
		}
	}

	honeypot := t.TempDir()
	witness := filepath.Join(honeypot, "witness")
	if err := os.WriteFile(witness, []byte("untouched"), 0o644); err != nil {
		t.Fatal(err)
	}

	fsys, err := DirFS(base)
	if err != nil {
		t.Fatal(err)
	}
	defer fsys.Close()

	stop := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		for {
			select {
			case <-stop:
				return
			default:
			}
			for i := 0; i < n; i++ {
				sub := filepath.Join(base, fmt.Sprintf("s%d", i))
				bak := sub + ".bak"
				if os.Rename(sub, bak) == nil {
					_ = os.Symlink(honeypot, sub)
					runtime.Gosched() // widen the swap window
					_ = os.Remove(sub)
					_ = os.Rename(bak, sub)
				}
			}
		}
	}()

	const nobodyUID, nobodyGID = 65534, 65534
	// Log (don't fail) on race-induced errors. A regression where the
	// walk never reaches anything would silently pass the honeypot check.
	if err := fsys.RecursiveChown(nobodyUID, nobodyGID); err != nil {
		t.Logf("RecursiveChown returned (likely from race): %v", err)
	}

	close(stop)
	wg.Wait()

	// Honeypot dir is the broader detector — sub.Lchown(".") fires before
	// ReadDir, so a leak hits the dir even if the attacker restores fast.
	for _, p := range []string{honeypot, witness} {
		info, err := os.Lstat(p)
		if err != nil {
			t.Fatalf("Lstat %s: %v", p, err)
		}
		st, ok := info.Sys().(*syscall.Stat_t)
		if !ok {
			t.Fatalf("%s stat is not *syscall.Stat_t", p)
		}
		if st.Uid == nobodyUID {
			t.Errorf("TOCTOU regression: %s was chowned to nobody", p)
		}
	}
}

func mkdir(t *testing.T, path string) {
	t.Helper()
	if err := os.Mkdir(path, 0o755); err != nil {
		t.Fatalf("Mkdir(%s): %v", path, err)
	}
}

func writeFile(t *testing.T, path string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("x"), 0o644); err != nil {
		t.Fatalf("WriteFile(%s): %v", path, err)
	}
}
