#!/usr/bin/env python3
"""
Ensure AMI metadata is set for Stack AMI builds.

This script checks if the packer build step set AMI metadata. If not,
it fetches the AMI ID from the main branch CloudFormation template,
which happens when the build was skipped due to if_changed conditions.
"""

import os
import re
import subprocess
import sys
import urllib.request
from typing import Optional


def get_metadata(key: str) -> Optional[str]:
    """Get metadata from Buildkite agent, return None if not found."""
    try:
        result = subprocess.run(
            ["buildkite-agent", "meta-data", "get", key],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except FileNotFoundError:
        print("Warning: buildkite-agent not found", file=sys.stderr)
    return None


def set_metadata(key: str, value: str) -> None:
    """Set metadata in Buildkite agent."""
    try:
        subprocess.run(
            ["buildkite-agent", "meta-data", "set", key, value],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"ERROR: Failed to set metadata: {e.stderr}", file=sys.stderr)
        raise
    except FileNotFoundError:
        print("ERROR: buildkite-agent not found", file=sys.stderr)
        raise


def fetch_ami_from_template(os_type: str, arch: str, region: str) -> str:
    """
    Fetch AMI ID from the main branch CloudFormation template.

    Args:
        os_type: Operating system (linux or windows)
        arch: Architecture (amd64 or arm64)
        region: AWS region

    Returns:
        AMI ID string

    Raises:
        RuntimeError: If AMI cannot be found
    """
    template_url = "https://s3.amazonaws.com/buildkite-aws-stack/main/aws-stack.yml"

    print(f"--- Fetching AMI ID from main branch template for {os_type}/{arch}")

    try:
        with urllib.request.urlopen(template_url) as response:
            template_content = response.read().decode("utf-8")
    except Exception as e:
        raise RuntimeError(
            f"Failed to download main branch template from {template_url}: {e}"
        ) from e

    if os_type == "windows":
        key_name = "windows"
    elif arch == "arm64":
        key_name = "linuxarm64"
    else:
        key_name = "linuxamd64"

    # Template format: "    us-east-1: { linuxamd64: ami-xxx, linuxarm64: ami-yyy, windows: ami-zzz }"
    pattern = rf"^\s+{re.escape(region)}\s*:.*{key_name}:\s*(ami-[a-z0-9]+)"

    for line in template_content.split("\n"):
        match = re.search(pattern, line)
        if match:
            ami_id = match.group(1)
            print(f"Found AMI ID: {ami_id}")
            return ami_id

    raise RuntimeError(
        f"Could not find AMI ID for region {region}, os {os_type}, arch {arch} in main template"
    )


def ensure_ami_metadata(os_type: str, arch: str) -> None:
    """
    Ensure AMI metadata is set, fetching from template if necessary.

    Args:
        os_type: Operating system (linux or windows)
        arch: Architecture (amd64 or arm64)
    """
    metadata_key = f"{os_type}_{arch}_image_id"

    existing_ami = get_metadata(metadata_key)
    if existing_ami:
        print(f"AMI metadata already set: {existing_ami}")
        return

    region = os.environ.get("AWS_REGION")
    if not region:
        raise RuntimeError("AWS_REGION environment variable not set")

    print("AMI metadata not found, fetching from main branch template...")
    ami_id = fetch_ami_from_template(os_type, arch, region)

    set_metadata(metadata_key, ami_id)
    print(f"Set AMI metadata: {metadata_key}={ami_id}")


def main() -> int:
    """Main entry point."""
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <os> <arch>", file=sys.stderr)
        print("  os:   linux or windows", file=sys.stderr)
        print("  arch: amd64 or arm64", file=sys.stderr)
        return 1

    os_type = sys.argv[1]
    arch = sys.argv[2]

    if os_type not in ("linux", "windows"):
        print(
            f"ERROR: Invalid OS '{os_type}', must be 'linux' or 'windows'",
            file=sys.stderr,
        )
        return 1

    if arch not in ("amd64", "arm64"):
        print(
            f"ERROR: Invalid arch '{arch}', must be 'amd64' or 'arm64'", file=sys.stderr
        )
        return 1

    try:
        ensure_ami_metadata(os_type, arch)
        return 0
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
