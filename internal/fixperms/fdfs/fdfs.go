//go:build linux

// Package fdfs is like os.DirFS, but with a file descriptor and openat(2),
// fchownat(2), etc, to ensure symlinks do not escape.
package fdfs

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"runtime"
	"sync/atomic"
	"time"

	"golang.org/x/sync/errgroup"
	"golang.org/x/sys/unix"
)

const (
	resolveFlags = unix.RESOLVE_BENEATH | unix.RESOLVE_NO_SYMLINKS | unix.RESOLVE_NO_MAGICLINKS | unix.RESOLVE_NO_XDEV

	heartbeatInterval = 30 * time.Second
)

// FS uses a file descriptor for a directory as the base of a fs.FS.
type FS struct {
	file *os.File
}

// DirFS opens the directory dir, and returns an FS rooted at that directory.
// It uses open(2) with O_RDONLY+O_DIRECTORY+O_CLOEXEC. Note that this will
// resolve symlinks in the path, so only use this to open a trusted base path.
func DirFS(dir string) (*FS, error) {
	f, err := os.OpenFile(dir, unix.O_RDONLY|unix.O_DIRECTORY|unix.O_CLOEXEC, 0)
	if err != nil {
		return nil, err
	}
	return &FS{file: f}, nil
}

// Close closes the file descriptor.
func (s *FS) Close() error {
	return s.file.Close()
}

// Open wraps openat2(2) with O_RDONLY+O_NOFOLLOW+O_CLOEXEC, and prohibits
// symlinks etc within the path.
func (s *FS) Open(path string) (fs.File, error) {
	fd, err := unix.Openat2(int(s.file.Fd()), path, &unix.OpenHow{
		Flags:   unix.O_RDONLY | unix.O_NOFOLLOW | unix.O_CLOEXEC,
		Mode:    0,
		Resolve: resolveFlags,
	})
	if err != nil {
		return nil, fmt.Errorf("openat2(%d, %q): %w", s.file.Fd(), path, err)
	}
	return os.NewFile(uintptr(fd), path), nil
}

// Lchown wraps fchownat(2) (with AT_SYMLINK_NOFOLLOW).
func (s *FS) Lchown(path string, uid, gid int) error {
	if err := unix.Fchownat(int(s.file.Fd()), path, uid, gid, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return fmt.Errorf("fchownat(%d, %q, %d, %d): %w", s.file.Fd(), path, uid, gid, err)
	}
	return nil
}

// Stat wraps fstatat(2) (with AT_SYMLINK_NOFOLLOW).
func (s *FS) Stat(path string) (*unix.Stat_t, error) {
	var stat unix.Stat_t
	if err := unix.Fstatat(int(s.file.Fd()), path, &stat, unix.AT_SYMLINK_NOFOLLOW); err != nil {
		return nil, fmt.Errorf("fstatat(%d, %q): %w", s.file.Fd(), path, err)
	}

	return &stat, nil
}

// Sub wraps openat2(2) (with O_RDONLY+O_DIRECTORY+O_NOFOLLOW+O_CLOEXEC), and
// returns an FS.
func (s *FS) Sub(dir string) (*FS, error) {
	fd, err := unix.Openat2(int(s.file.Fd()), dir, &unix.OpenHow{
		Flags:   unix.O_RDONLY | unix.O_DIRECTORY | unix.O_NOFOLLOW | unix.O_CLOEXEC,
		Mode:    0,
		Resolve: resolveFlags,
	})
	if err != nil {
		return nil, fmt.Errorf("openat2(%d, %q): %w", s.file.Fd(), dir, err)
	}
	return &FS{os.NewFile(uintptr(fd), dir)}, nil
}

// RecursiveChown lchowns everything within the receiver.
// Not safe for concurrent calls on the same receiver.
func (s *FS) RecursiveChown(uid, gid int) error {
	// Q: Why not fs.WalkDir(... s.Lchown(path, uid, gid) ... ) ?
	// A: fs.WalkDir gives the callback a subpath to each item. So although
	//    fs.WalkDir doesn't traverse symlinks, there's a race between walking
	//    each path (no intermediate symlinks), and passing that path to lchown
	//    (has possibly changed).
	//    Solution: More openat.

	if err := s.Lchown(".", uid, gid); err != nil {
		return err
	}

	g, ctx := errgroup.WithContext(context.Background())
	g.SetLimit(min(128, max(1, 2*runtime.GOMAXPROCS(0))))

	var files, dirs atomic.Uint64
	stop := startHeartbeat(&files, &dirs)
	defer stop()

	g.Go(func() error {
		return walkContents(ctx, g, s, uid, gid, &files, &dirs)
	})
	return g.Wait()
}

// walkContents walks fsys's entries and dispatches subdirs via g.TryGo
// with inline fallback (avoids deadlock when every worker is in
// dispatch). Does not close fsys.
func walkContents(ctx context.Context, g *errgroup.Group, fsys *FS, uid, gid int, files, dirs *atomic.Uint64) error {
	if err := ctx.Err(); err != nil {
		return err
	}

	ds, err := fsys.file.ReadDir(-1)
	if err != nil {
		if raceErr(err) {
			return nil
		}
		return err
	}
	dirs.Add(1)

	for _, d := range ds {
		if err := ctx.Err(); err != nil {
			return err
		}

		if !d.IsDir() {
			// Skip lchown if the uid and gid already match. This avoids updating
			// the ctime of files unnecessarily.
			stat, err := fsys.Stat(d.Name())
			if err != nil {
				if raceErr(err) {
					continue
				}
				return err
			}
			files.Add(1)
			if int(stat.Uid) == uid && int(stat.Gid) == gid {
				continue
			}
			if err := fsys.Lchown(d.Name(), uid, gid); err != nil {
				if raceErr(err) {
					continue
				}
				return err
			}
			continue
		}

		// Defensively check we're not about to recurse on a symlink.
		// (The openat2 call in fsys.Sub will block it anyway.)
		if d.Type()&fs.ModeSymlink != 0 {
			continue
		}

		sub, err := fsys.Sub(d.Name())
		if err != nil {
			if raceErr(err) {
				continue
			}
			return err
		}
		walk := func() error {
			defer sub.Close()
			if err := sub.Lchown(".", uid, gid); err != nil {
				if raceErr(err) {
					return nil
				}
				return err
			}
			return walkContents(ctx, g, sub, uid, gid, files, dirs)
		}
		if !g.TryGo(walk) {
			if err := walk(); err != nil {
				return err
			}
		}
	}
	return nil
}

// startHeartbeat emits a progress line to stderr every heartbeatInterval
// with a verdict for stalled walks. Returns a func that stops the
// goroutine and waits for exit.
func startHeartbeat(files, dirs *atomic.Uint64) func() {
	stop := make(chan struct{})
	done := make(chan struct{})

	go func() {
		defer close(done)

		startWall := time.Now()
		var lastRU unix.Rusage
		_ = unix.Getrusage(unix.RUSAGE_SELF, &lastRU)

		lastWall := startWall
		lastFiles := uint64(0)
		problemTicks := 0
		hintShown := false

		ticker := time.NewTicker(heartbeatInterval)
		defer ticker.Stop()

		for {
			select {
			case now := <-ticker.C:
				f := files.Load()
				d := dirs.Load()

				interval := now.Sub(lastWall).Seconds()
				rate := 0.0
				if interval > 0 {
					rate = float64(f-lastFiles) / interval
				}

				var ru unix.Rusage
				_ = unix.Getrusage(unix.RUSAGE_SELF, &ru)
				intervalCPU := rusageCPU(ru) - rusageCPU(lastRU)
				cpuPerCore := 0.0
				if interval > 0 {
					cpuPerCore = 100 * intervalCPU.Seconds() / interval / float64(runtime.GOMAXPROCS(0))
				}
				wall := now.Sub(startWall)

				verdict := ""
				switch {
				case rate < 100:
					verdict = " — barely making progress (check for disk hang or severe EBS throttling)"
					problemTicks++
				case rate < 2000 && cpuPerCore < 25:
					verdict = " — EBS-bound (mostly blocked on disk I/O)"
					problemTicks++
				default:
					problemTicks = 0
				}
				if problemTicks >= 2 && !hintShown {
					verdict += " — set DOCKER_USERNS_REMAP=true to skip fix-perms entirely, or provision more EBS IOPS"
					hintShown = true
				}

				fmt.Fprintf(os.Stderr,
					"fix-perms: %d files (%.0f/s), %d dirs in %s, CPU %.0f%%/core%s\n",
					f, rate, d, wall.Round(time.Second), cpuPerCore, verdict,
				)

				lastFiles = f
				lastWall = now
				lastRU = ru
			case <-stop:
				return
			}
		}
	}()

	return func() {
		close(stop)
		<-done
	}
}

// raceErr reports errors indicating the entry changed concurrently
// (unlinked, replaced, cross-mount). Real failures are returned.
func raceErr(err error) bool {
	return errors.Is(err, unix.ENOENT) ||
		errors.Is(err, unix.ELOOP) ||
		errors.Is(err, unix.ENOTDIR) ||
		errors.Is(err, unix.EXDEV)
}

// rusageCPU returns user+system CPU time from a Rusage.
func rusageCPU(r unix.Rusage) time.Duration {
	user := time.Duration(r.Utime.Sec)*time.Second + time.Duration(r.Utime.Usec)*time.Microsecond
	sys := time.Duration(r.Stime.Sec)*time.Second + time.Duration(r.Stime.Usec)*time.Microsecond
	return user + sys
}
