"""Run the storage script with disposable paths and simulated disk commands.

Real mdadm/filesystem behavior is covered separately on disposable EC2 stacks.
These tests protect the script's preservation and persistence decisions in CI.
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

# Existing arrays refuse creation. Formatting destroys the simulated sentinel,
# so preservation assertions also catch accidentally reintroducing mkfs.
DISK_COMMANDS = r'''
set -Eeuo pipefail
nvme() {
  printf '/dev/nvme2n1 Amazon EC2 NVMe Instance Storage\n/dev/nvme1n1 Amazon EC2 NVMe Instance Storage\n'
}
findmnt() {
  [[ -f "$STATE_DIR/mounted" ]] || return 1
  case "$*" in
    *SOURCE*) echo /dev/md0 ;;
    *FSTYPE*) cat "$STATE_DIR/filesystem" ;;
  esac
}
mdadm() {
  case "$1" in
    --detail)
      if [[ "$2" == --scan ]]; then echo 'ARRAY /dev/md0'; else [[ -f "$STATE_DIR/active" ]]; fi ;;
    --examine) return 0 ;;
    --assemble) touch "$STATE_DIR/active" ;;
    --create) return 2 ;;
  esac
}
blkid() { cat "$STATE_DIR/filesystem"; }
mount() { touch "$STATE_DIR/mounted"; }
mkfs.ext4() { echo ext4 > "$STATE_DIR/filesystem"; rm "$STATE_DIR/sentinel"; }
blockdev() { :; }
logger() { cat; }
source "$1"
'''


class StorageScriptTest(unittest.TestCase):
    def test_existing_storage_is_preserved(self):
        cases = (
            ("active array", False, "ext4", True, False, True),
            ("stopped array", False, "ext4", False, False, True),
            ("mounted missing fstab", True, "ext4", True, False, True),
            ("unmounted xfs", False, "xfs", True, False, False),
            ("mounted xfs missing fstab", True, "xfs", True, False, False),
            ("foreign active array", False, "ext4", True, True, False),
        )
        for name, mounted, filesystem, active, foreign, success in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                (work / "filesystem").write_text(filesystem)
                (work / "sentinel").write_text("existing build data")
                (work / "fstab").write_text("")
                if mounted:
                    (work / "mounted").touch()
                if active:
                    (work / "active").touch()
                members = work / "sys/block/md0/slaves"
                members.mkdir(parents=True)
                for member in (("loop0", "loop1") if foreign else ("nvme1n1", "nvme2n1")):
                    (members / member).touch()

                source = (ROOT / "packer/linux/stack/conf/bin/bk-mount-instance-storage.sh").read_text()
                # Remap system paths, not script logic; nothing requires root.
                for original, replacement in (
                    ("/mnt/ephemeral", str(work / "mount")),
                    ("/etc/fstab", str(work / "fstab")),
                    ("/etc/mdadm.conf", str(work / "mdadm.conf")),
                    ("/sys/block/", str(work / "sys/block") + "/"),
                    ("/var/log/elastic-stack.log", str(work / "storage.log")),
                    ("/dev/console", str(work / "console")),
                ):
                    source = source.replace(original, replacement)
                script = work / "storage.sh"
                script.write_text(source)
                env = dict(os.environ, STATE_DIR=str(work), BUILDKITE_ENABLE_INSTANCE_STORAGE="true",
                           BUILDKITE_MOUNT_TMPFS_AT_TMP="true")
                for _ in range(2):
                    result = subprocess.run(["bash", "-c", DISK_COMMANDS, "test", str(script)],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0 if success else 1,
                                     result.stdout + result.stderr)
                    self.assertEqual((work / "sentinel").read_text(), "existing build data")
                    self.assertEqual((work / "filesystem").read_text(), filesystem)
                    self.assertEqual((work / "mounted").exists(), mounted or success)
                    entries = [line.split() for line in (work / "fstab").read_text().splitlines()]
                    self.assertEqual(entries, [["/dev/md0", str(work / "mount"), "ext4",
                                                "defaults,noatime", "0", "0"]] if success else [])


if __name__ == "__main__":
    unittest.main()
