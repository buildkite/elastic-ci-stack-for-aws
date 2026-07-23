#!/usr/bin/env python3
# Fail if goss.yaml gains a check that goss.ubuntu2404.yaml doesn't mirror.
#
# goss.ubuntu2404.yaml documents its intentional divergences from goss.yaml
# in its header comment; those are the exceptions below. Anything else in
# goss.yaml is expected to have a same-keyed entry in goss.ubuntu2404.yaml.
import sys

import yaml

EXCEPTIONS = {
    "file": {"/home/ec2-user/.ssh/authorized_keys"},
    "service": {"amazon-ssm-agent", "sshd"},
    "group": {"sshd"},
    "process": {"sshd"},
    "command": {'getent group docker | cut -d: -f3 | grep -E "^99[0-5]$"'},
}

with open("goss.yaml") as f:
    base = yaml.safe_load(f)
with open("goss.ubuntu2404.yaml") as f:
    ubuntu = yaml.safe_load(f)

missing = []
for section, checks in base.items():
    excepted = EXCEPTIONS.get(section, set())
    ubuntu_keys = set((ubuntu.get(section) or {}).keys())
    for key in checks:
        if key in excepted:
            continue
        if key not in ubuntu_keys:
            missing.append(f"{section}: {key!r}")

if missing:
    print("goss.ubuntu2404.yaml is missing checks present in goss.yaml:")
    for m in missing:
        print(f"  - {m}")
    print()
    print("Either add the check to goss.ubuntu2404.yaml, or if it's an intentional")
    print("AL2023-only divergence, document it in goss.ubuntu2404.yaml's header")
    print("comment and add it to EXCEPTIONS in .buildkite/scripts/check-goss-sync.py.")
    sys.exit(1)

print("goss.yaml and goss.ubuntu2404.yaml are in sync.")
