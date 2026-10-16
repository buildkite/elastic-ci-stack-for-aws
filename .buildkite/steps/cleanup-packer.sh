#!/bin/bash
set -euo pipefail

# Terminates Packer builder instances launched more than 24 hours ago, whatever
# state their build is in, including stopped instances. Only instances carrying
# every tag this repository's Packer templates set are considered. Volumes,
# AMIs and snapshots are left alone.
#
# Like clean-old-amis, any set DRY_RUN value previews; unset it to terminate.

account_id=172840064832
region=us-east-1

date_cmd="date"
if [[ $OSTYPE =~ ^darwin ]]; then
  date_cmd=gdate
fi
cutoff=$(($("$date_cmd" -u +%s) - 24 * 60 * 60))

# Every call below names the region explicitly, but refuse to run when the
# caller is configured for another one rather than silently switching.
caller_region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
if [[ -z "$caller_region" ]]; then
  caller_region="$(aws configure get region)" || caller_region=""
fi
if [[ "$caller_region" != "$region" ]]; then
  echo "Refusing to run with AWS region '${caller_region}', expected ${region}" >&2
  exit 1
fi

caller_account="$(aws sts get-caller-identity --region "$region" --query Account --output text)"
if [[ "$caller_account" != "$account_id" ]]; then
  echo "Refusing to run in AWS account ${caller_account}, expected ${account_id}" >&2
  exit 1
fi

echo "--- Finding Packer builders launched more than 24 hours ago"
instances="$(aws ec2 describe-instances \
  --region "$region" \
  --filters \
  "Name=tag:Name,Values=Packer Builder" \
  "Name=tag:ManagedBy,Values=elastic-ci-stack-for-aws" \
  "Name=tag:Purpose,Values=disposable-ci" \
  "Name=tag-key,Values=BuildNumber" \
  "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[].Instances[].[InstanceId, LaunchTime]' \
  --output text)"

expired=()
while read -r instance_id launch_time; do
  [[ -n "$instance_id" ]] || continue
  launched="$("$date_cmd" -u -d "$launch_time" +%s)"
  if [[ "$launched" -lt "$cutoff" ]]; then
    expired+=("$instance_id")
  fi
done <<<"$instances"

if [[ "${#expired[@]}" -eq 0 ]]; then
  echo "None found"
  exit 0
fi

echo "Found: ${expired[*]}"
if [[ -n "${DRY_RUN+set}" ]]; then
  echo "DRY_RUN is set: not terminating them"
  exit 0
fi

aws ec2 terminate-instances \
  --region "$region" \
  --instance-ids "${expired[@]}" \
  --query 'TerminatingInstances[].[InstanceId, CurrentState.Name]' \
  --output text
