//go:build linux

// Package fdfs is like os.DirFS, but with a file descriptor and openat(2),
// fchownat(2), etc, to ensure symlinks do not escape.
package fdfs

import (
	"fmt"
	"io/fs"
	"os"

	"golang.org/x/sys/unix"
)

const resolveFlags = unix.RESOLVE_BENEATH | unix.RESOLVE_NO_SYMLINKS | unix.RESOLVE_NO_MAGICLINKS | unix.RESOLVE_NO_XDEV

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

	// This closure exists so sd.Close happens before the next loop iteration,
	// rather than at the end of RecursiveChown.
	chownSubdir := func(name string) error {
		sd, err := s.Sub(name)
		if err != nil {
			return err
		}
		defer sd.Close()
		return sd.RecursiveChown(uid, gid)
	}

	// The "file" within an *FS should always be a directory.
	ds, err := s.file.ReadDir(-1)
	if err != nil {
		return err
	}
	for _, d := range ds {
		if !d.IsDir() {
			// Skip lchown if the uid and gid already match. This avoids updating
			// the ctime of files unnecessarily.
			stat, err := s.Stat(d.Name())
			if err != nil {
				return err
			}
			if int(stat.Uid) == uid && int(stat.Gid) == gid {
				continue
			}

			if err := s.Lchown(d.Name(), uid, gid); err != nil {
				return err
			}
			continue
		}

		// Defensively check we're not about to recurse on a symlink.
		// (The openat2 call in s.Sub will block it anyway.)
		if d.Type()&fs.ModeSymlink != 0 {
			continue
		}

		if err := chownSubdir(d.Name()); err != nil {
			return err
		}
	}
	return nil
}
