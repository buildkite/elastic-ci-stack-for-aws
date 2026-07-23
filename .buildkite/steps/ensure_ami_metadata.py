#!/usr/bin/env python3
"""
Ensure AMI metadata is set for Stack AMI builds.

This script checks if the packer build step set AMI metadata. If not,
it fetches the AMI ID from a fallback source. For standard builds, the
fallback is the main branch CloudFormation template on S3. For CIS builds,
the fallback is the latest CIS stack AMI output file on S3 (since CIS AMIs
are private and not published in the CloudFormation template).

This allows launch/test/delete steps to use a broader if_changed scope
than the packer build step: when only launch scripts or templates change,
the packer step is skipped but the launch/test/delete chain still runs
against the most recently built AMI.
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
    elif os_type == "ubuntu2404":
        key_name = "ubuntu2404arm64" if arch == "arm64" else "ubuntu2404amd64"
    elif arch == "arm64":
        key_name = "linuxarm64"
    else:
        key_name = "linuxamd64"

    # Template format: "    us-east-1: { linuxamd64: ami-xxx, linuxarm64: ami-yyy, windows: ami-zzz, ubuntu2404amd64: ami-aaa, ubuntu2404arm64: ami-bbb }"
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


def fetch_ami_from_s3(os_type: str, arch: str, region: str, variant: str) -> str:
    """
    Fetch AMI ID from the latest packer output file on S3.

    Used for variants (like CIS) that are not published in the
    CloudFormation template.

    Args:
        os_type: Operating system (linux or windows)
        arch: Architecture (amd64 or arm64)
        region: AWS region
        variant: Build variant (e.g. "cis")

    Returns:
        AMI ID string

    Raises:
        RuntimeError: If AMI cannot be found
    """
    bucket = os.environ.get("BUILDKITE_AWS_STACK_BUCKET")
    if not bucket:
        raise RuntimeError("BUILDKITE_AWS_STACK_BUCKET environment variable not set")

    s3_key = f"packer-{os_type}-{arch}-{variant}-latest.output"
    s3_path = f"s3://{bucket}/{s3_key}"
    local_path = f"/tmp/{s3_key}"

    print(f"--- Fetching AMI ID from S3 for {os_type}/{arch}/{variant}")

    try:
        subprocess.run(
            ["aws", "s3", "cp", s3_path, local_path],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f"Failed to download {s3_path}: {e.stderr}. "
            f"Has a {variant} build completed on main branch?"
        ) from e

    try:
        with open(local_path) as f:
            content = f.read()
    finally:
        os.remove(local_path)

    pattern = rf"{re.escape(region)}: (ami-[a-z0-9]+)"
    match = re.search(pattern, content)
    if match:
        ami_id = match.group(1)
        print(f"Found AMI ID: {ami_id}")
        return ami_id

    raise RuntimeError(
        f"Could not find AMI ID for region {region} in {s3_key}"
    )


def ensure_ami_metadata(os_type: str, arch: str, variant: Optional[str] = None) -> None:
    """
    Ensure AMI metadata is set, fetching from a fallback if necessary.

    For standard builds, falls back to the published CloudFormation template.
    For variant builds (e.g. CIS), falls back to the latest S3 output file.

    Args:
        os_type: Operating system (linux or windows)
        arch: Architecture (amd64 or arm64)
        variant: Optional build variant (e.g. "cis")
    """
    if variant:
        metadata_key = f"{os_type}_{arch}_{variant}_image_id"
    else:
        metadata_key = f"{os_type}_{arch}_image_id"

    existing_ami = get_metadata(metadata_key)
    if existing_ami:
        print(f"AMI metadata already set: {existing_ami}")
        return

    region = os.environ.get("AWS_REGION")
    if not region:
        raise RuntimeError("AWS_REGION environment variable not set")

    print("AMI metadata not found, fetching from fallback source...")

    if variant:
        ami_id = fetch_ami_from_s3(os_type, arch, region, variant)
    else:
        ami_id = fetch_ami_from_template(os_type, arch, region)

    set_metadata(metadata_key, ami_id)
    print(f"Set AMI metadata: {metadata_key}={ami_id}")


def main() -> int:
    """Main entry point."""
    if len(sys.argv) < 3 or len(sys.argv) > 4:
        print(f"Usage: {sys.argv[0]} <os> <arch> [variant]", file=sys.stderr)
        print("  os:      linux, windows or ubuntu2404", file=sys.stderr)
        print("  arch:    amd64 or arm64", file=sys.stderr)
        print("  variant: optional build variant (e.g. cis)", file=sys.stderr)
        return 1

    os_type = sys.argv[1]
    arch = sys.argv[2]
    variant = sys.argv[3] if len(sys.argv) == 4 else None

    if os_type not in ("linux", "windows", "ubuntu2404"):
        print(
            f"ERROR: Invalid OS '{os_type}', must be 'linux', 'windows' or 'ubuntu2404'",
            file=sys.stderr,
        )
        return 1

    if arch not in ("amd64", "arm64"):
        print(
            f"ERROR: Invalid arch '{arch}', must be 'amd64' or 'arm64'", file=sys.stderr
        )
        return 1

    try:
        ensure_ami_metadata(os_type, arch, variant)
        return 0
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
