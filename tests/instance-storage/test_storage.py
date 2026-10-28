"""Run the storage script with disposable paths and simulated disk commands.

Real mdadm/filesystem behavior is covered separately on disposable EC2 stacks.
These tests protect the script's preservation and persistence decisions in CI.
"""

from fnmatch import fnmatch
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]

# Existing arrays refuse creation. Formatting destroys the simulated sentinel,
# so preservation assertions also catch accidentally reintroducing mkfs.
DISK_COMMANDS = r'''
set -Eeuo pipefail
nvme() {
  if [[ "$DEVICE_COUNT" == 1 ]]; then
    printf '/dev/nvme1n1 Amazon EC2 NVMe Instance Storage\n'
    return
  fi
  printf '/dev/nvme2n1 Amazon EC2 NVMe Instance Storage\n/dev/nvme1n1 Amazon EC2 NVMe Instance Storage\n'
}
findmnt() {
  [[ -f "$STATE_DIR/mounted" ]] || return 1
  case "$*" in
    *SOURCE*) echo "$STORAGE_DEVICE" ;;
    *FSTYPE*) cat "$STATE_DIR/filesystem" ;;
  esac
}
mdadm() {
  [[ "$DEVICE_COUNT" == 2 ]] || exit 99
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

INSTALL_COMMANDS = r'''
set -Eeuo pipefail
curl() { echo i-test; }
docker() { echo 'Docker version 25.0.0, build test'; }
aws() { echo "$TEST_AGENT_TOKEN"; }
chown() { :; }
su() { :; }
systemctl() { :; }
getent() { echo 'ec2-user:x:1000:1000::/home/ec2-user:/bin/bash'; }
logger() { cat; }
findmnt() {
  [[ "$1" == --mountpoint ]] || exit 99
  awk -v path="$2" '$2 == path {found=1} END {exit !found}' "$STATE_DIR/mounts"
}
mount() {
  [[ "$1 $2" == '-o bind' ]]
  printf '%s\t%s\n' "$3" "$4" >> "$STATE_DIR/mounts"
}
source "$1"
'''


class StorageScriptTest(unittest.TestCase):
    def test_existing_storage_is_preserved(self):
        cases = (
            ("active array", 2, False, "ext4", True, False, True),
            ("stopped array", 2, False, "ext4", False, False, True),
            ("mounted missing fstab", 2, True, "ext4", True, False, True),
            ("unmounted xfs", 2, False, "xfs", True, False, False),
            ("mounted xfs missing fstab", 2, True, "xfs", True, False, False),
            ("foreign active array", 2, False, "ext4", True, True, False),
            ("single ext4 device", 1, False, "ext4", False, False, True),
            ("single xfs device", 1, False, "xfs", False, False, False),
        )
        for name, count, mounted, filesystem, active, foreign, success in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                device = "/dev/nvme1n1" if count == 1 else "/dev/md0"
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
                env = dict(os.environ, STATE_DIR=str(work), DEVICE_COUNT=str(count), STORAGE_DEVICE=device,
                           BUILDKITE_ENABLE_INSTANCE_STORAGE="true",
                           BUILDKITE_MOUNT_TMPFS_AT_TMP="true")
                for _ in range(2):
                    result = subprocess.run(["bash", "-c", DISK_COMMANDS, "test", str(script)],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0 if success else 1,
                                     result.stdout + result.stderr)
                    self.assertTrue((work / "sentinel").exists(), "Existing storage data was formatted")
                    self.assertEqual((work / "sentinel").read_text(), "existing build data")
                    self.assertEqual((work / "filesystem").read_text(), filesystem)
                    self.assertEqual((work / "mounted").exists(), mounted or success)
                    entries = [line.split() for line in (work / "fstab").read_text().splitlines()]
                    self.assertEqual(entries, [[device, str(work / "mount"), "ext4",
                                                "defaults,noatime", "0", "0"]] if success else [])
                    if success and not mounted and count == 2:
                        config = (work / "mdadm.conf").read_text().splitlines()
                        self.assertTrue(any(line.startswith("ARRAY ") for line in config))
                        # EC2 can renumber a member after reboot. mdadm must
                        # still discover it using the persisted configuration.
                        patterns = [word for line in config if line.startswith("DEVICE ")
                                    for word in line.split()[1:]]
                        self.assertTrue(not patterns or "partitions" in patterns or
                                        any(fnmatch("/dev/nvme3n1", p) for p in patterns),
                                        "RAID discovery excludes a renumbered instance-store member")

    def test_installer_restores_bind_mount_persistence_without_stacking_mounts(self):
        for mounted in (False, True):
            with self.subTest(mounted=mounted), tempfile.TemporaryDirectory() as directory:
                work = Path(directory)
                for path in ("etc/buildkite-agent", "var/lib/buildkite-agent", "var/log", "usr/bin"):
                    (work / path).mkdir(parents=True)
                fstab = work / "etc/fstab"
                fstab.write_text("")
                mounts = work / "mounts"
                expected = [[str(work / "mnt/ephemeral" / name),
                             str(work / "var/lib/buildkite-agent" / name)]
                            for name in ("git-mirrors", "builds")]
                mounts.write_text("".join("\t".join(entry) + "\n" for entry in expected) if mounted else "")
                source = (ROOT / "packer/linux/stack/conf/bin/bk-install-elastic-stack.sh").read_text()
                # Run the entire installer, redirecting only filesystem paths
                # and replacing privileged/external commands, not its logic.
                source = re.sub(r"/(?:etc|var|usr|mnt)/", lambda match: str(work) + match[0], source)
                source = source.replace("/dev/console", str(work / "console"))
                script = work / "installer.sh"
                script.write_text(source)
                env = dict(os.environ, STATE_DIR=str(work))
                for key in """
                    BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS BUILDKITE_AGENTS_PER_INSTANCE
                    BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME BUILDKITE_AGENT_EXPERIMENTS
                    BUILDKITE_AGENT_JOB_VERIFICATION_NO_SIGNATURE_BEHAVIOR
                    BUILDKITE_AGENT_SIGNING_KEY_ID BUILDKITE_AGENT_SIGNING_KEY_PATH
                    BUILDKITE_AGENT_SIGNING_KMS_KEY BUILDKITE_AGENT_TOKEN_PATH
                    BUILDKITE_AGENT_VERIFICATION_KEY_PATH BUILDKITE_ARTIFACTS_BUCKET
                    BUILDKITE_AUTHORIZED_USERS_URL BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT
                    BUILDKITE_ENV_FILE_URL BUILDKITE_PURGE_BUILDS_ON_DISK_FULL
                    BUILDKITE_QUEUE BUILDKITE_SCALE_IN_IDLE_PERIOD BUILDKITE_SECRETS_BUCKET
                    BUILDKITE_SECRETS_BUCKET_REGION BUILDKITE_STACK_VERSION
                    BUILDKITE_S3_ACL BUILDKITE_S3_DEFAULT_REGION BUILDKITE_GIT_MIRROR_SEED_BUCKET
                    BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL
                    DOCKER_BUILDER_PRUNE_ENABLED DOCKER_EXPERIMENTAL DOCKER_PRUNE_UNTIL
                    DOCKER_USERNS_REMAP ECR_CREDENTIAL_HELPER_ENABLED ENABLE_PRE_EXIT_DISK_CLEANUP
                """.split():
                    env[key] = ""
                env.update(AWS_REGION="us-east-1", BUILDKITE_AGENT_RELEASE="stable",
                           BUILDKITE_STACK_NAME="test", BUILDKITE_STACK_DEPLOYED_BY="test",
                           BUILDKITE_AGENT_ENABLE_GIT_MIRRORS="true", BUILDKITE_ENABLE_INSTANCE_STORAGE="true",
                           SECRETS_PLUGIN_ENABLED="false", ECR_PLUGIN_ENABLED="false",
                           DOCKER_LOGIN_PLUGIN_ENABLED="false", ENABLE_RESOURCE_LIMITS="false",
                           ENABLE_EC2_LOG_RETENTION_POLICY="false")
                status = work / "var/log/elastic-stack-bootstrap-status"
                for run in range(2):
                    # Model fresh initialization with existing mounts/config.
                    # Leaving Completed in place would only test the early exit.
                    if status.exists():
                        status.unlink()
                    env["TEST_AGENT_TOKEN"] = f"test-token-{run}"
                    result = subprocess.run(["bash", "-c", INSTALL_COMMANDS, "test", str(script)],
                                            env=env, capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(status.read_text().strip(), "Completed")
                    config = (work / "etc/buildkite-agent/buildkite-agent.cfg").read_text()
                    self.assertIn(f'token="test-token-{run}"', config)
                    self.assertEqual([line.split() for line in mounts.read_text().splitlines()], expected)
                    self.assertEqual([line.split() for line in fstab.read_text().splitlines()],
                                     [entry + ["none", "defaults,bind", "0", "0"] for entry in expected])


if __name__ == "__main__":
    unittest.main()
