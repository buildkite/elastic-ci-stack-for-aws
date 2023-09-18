//go:build linux

// Package fdfs is like os.DirFS, but with a file descriptor and openat(2),
// fchownat(2), etc, to ensure symlinks do not escape.
package fdfs

import (
	"io/fs"
	"os"

	"golang.org/x/sys/unix"
)

const resolveFlags = unix.RESOLVE_BENEATH | unix.RESOLVE_NO_SYMLINKS | unix.RESOLVE_NO_MAGICLINKS | unix.RESOLVE_NO_XDEV

// FS uses a file descriptor for a directory as the base of a fs.FS.
type FS uintptr

// DirFS opens the directory dir, and returns an FS rooted at that directory.
// It uses open(2) with O_PATH+O_DIRECTORY+O_CLOEXEC.
func DirFS(dir string) (FS, error) {
	bd, err := os.OpenFile(dir, unix.O_PATH|unix.O_DIRECTORY|unix.O_CLOEXEC, 0)
	if err != nil {
		return 0, err
	}
	return FS(bd.Fd()), nil
}

// Close closes the file descriptor.
func (s FS) Close() error {
	return unix.Close(int(s))
}

// Open wraps openat2(2) with O_RDONLY+O_NOFOLLOW+O_CLOEXEC.
func (s FS) Open(path string) (fs.File, error) {
	fd, err := unix.Openat2(int(s), path, &unix.OpenHow{
		Flags:   unix.O_RDONLY | unix.O_NOFOLLOW | unix.O_CLOEXEC,
		Mode:    0,
		Resolve: resolveFlags,
	})
	if err != nil {
		return nil, err
	}
	f := os.NewFile(uintptr(fd), path)
	return f, nil
}

// Lchown wraps fchownat(2) (with AT_SYMLINK_NOFOLLOW).
func (s FS) Lchown(path string, uid, gid int) error {
	return unix.Fchownat(int(s), path, uid, gid, unix.AT_SYMLINK_NOFOLLOW)
}

// Sub wraps openat2(2) (with O_PATH+O_DIRECTORY+O_NOFOLLOW+O_CLOEXEC), and returns an FS.
func (s FS) Sub(dir string) (FS, error) {
	subFD, err := unix.Openat2(int(s), dir, &unix.OpenHow{
		Flags:   unix.O_PATH | unix.O_DIRECTORY | unix.O_NOFOLLOW | unix.O_CLOEXEC,
		Mode:    0,
		Resolve: resolveFlags,
	})
	if err != nil {
		return 0, err
	}
	return FS(subFD), nil
}
