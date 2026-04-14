#!/usr/bin/env bash

set -Eeuo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

on_error() {
  local exit_code="$?"
  local error_line="$1"

  echo "${BASH_SOURCE[0]} errored with exit code ${exit_code} on line ${error_line}."

  if [[ $exit_code != 0 ]]; then
    # Only try to set instance health if we have an instance ID
    # (metadata service must be available for this to work)
    if [[ -n "${INSTANCE_ID:-}" ]]; then
      if ! aws autoscaling set-instance-health \
        --instance-id "$INSTANCE_ID" \
        --health-status Unhealthy; then
        echo Failed to set instance health to unhealthy.
      fi
    else
      echo "Skipping instance health check - INSTANCE_ID not available (metadata service may be unavailable)"
    fi
  fi

  # Attempt to signal CloudFormation failure
  # This may fail if metadata service is unavailable, but we try anyway
  if [[ "${BUILDKITE_STACK_DEPLOYED_BY:-}" == "cloudformation" ]]; then
    if ! cfn-signal \
      --region "$AWS_REGION" \
      --stack "$BUILDKITE_STACK_NAME" \
      --reason "Error on line $error_line: $(tail -n 1 /var/log/elastic-stack.log)" \
      --resource "AgentAutoScaleGroup" \
      --exit-code "$exit_code"; then
      echo "Failed to send cfn-signal (this is expected if metadata service is unavailable)"
    fi
  else
    echo "Skipping cfn-signal (not deployed by CloudFormation)"
  fi

  # The OnFailure=poweroff.target in cloud-final.service.d will handle instance termination
  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

on_exit() {
  echo "${BASH_SOURCE[0]} completed successfully."
}

trap '[[ $? = 0 ]] && on_exit' EXIT

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting ${BASH_SOURCE[0]}..."

# This needs to happen first so that the error reporting works
# Fetch metadata with retry logic to handle transient metadata service failures
fetch_metadata_with_retry() {
  local max_attempts=5
  local timeout=2
  local wait_time=1
  local max_wait=30
  local attempt=1

  echo "Fetching EC2 metadata with retry (max attempts: $max_attempts)..."

  # Temporarily disable exit on error for retry logic
  set +e

  while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt of $max_attempts to fetch metadata..."

    # Try to get the token
    local token
    token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" \
      --max-time "$timeout" \
      --fail --silent --show-error \
      --location http://169.254.169.254/latest/api/token 2>&1)
    local token_result=$?

    if [[ $token_result -eq 0 ]]; then
      # Try to get the instance ID
      INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $token" \
        --max-time "$timeout" \
        --fail --silent --show-error \
        --location http://169.254.169.254/latest/meta-data/instance-id 2>&1)
      local instance_id_result=$?

      if [[ $instance_id_result -eq 0 ]]; then
        echo "Successfully fetched metadata on attempt $attempt"
        echo "Detected INSTANCE_ID=$INSTANCE_ID"
        # Re-enable exit on error
        set -e
        return 0
      else
        echo "Failed to fetch instance ID: $INSTANCE_ID"
      fi
    else
      echo "Failed to fetch metadata token: $token"
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      echo "Waiting ${wait_time}s before retry..."
      sleep "$wait_time"
      # Exponential backoff with cap at 30 seconds
      wait_time=$((wait_time * 2))
      if [[ $wait_time -gt $max_wait ]]; then
        wait_time=$max_wait
      fi
    fi

    attempt=$((attempt + 1))
  done

  # Re-enable exit on error before returning failure
  set -e

  echo "ERROR: Failed to fetch EC2 metadata after $max_attempts attempts"
  echo "This likely indicates the EC2 metadata service is unavailable or this instance has connectivity issues"

  # Return failure - this will trigger the error trap and call on_error()
  return 1
}

# Fetch metadata or fail (which triggers on_error and poweroff)
fetch_metadata_with_retry

# This script is run on every boot so that we can gracefully recover from hard failures (eg. kernel panics) during
# any previous attempts. If a previous run is detected as started but not complete then we will fail this run and mark
# the instance as unhealthy.
STATUS_FILE=/var/log/elastic-stack-bootstrap-status

check_status() {
  echo "Checking status file $STATUS_FILE..."

  if [[ -f "$STATUS_FILE" ]]; then
    if [[ "$(<"$STATUS_FILE")" == "Completed" ]]; then
      echo Bootstrap already completed successfully.
      exit 0
    else
      echo Bootstrap previously failed, will not continue from unknown state.
      return 1
    fi
  fi

  echo "Started" >"$STATUS_FILE"
}

check_status

case $(uname -m) in
x86_64) ARCH=amd64 ;;
aarch64) ARCH=arm64 ;;
*) ARCH=unknown ;;
esac
echo "Detected ARCH=$ARCH"

DOCKER_VERSION=$(docker --version | cut -f3 -d' ' | sed 's/,//')
echo "Detected DOCKER_VERSION=$DOCKER_VERSION"

PLUGINS_ENABLED=()
[[ $SECRETS_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("secrets")
[[ $ECR_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("ecr")
[[ $DOCKER_LOGIN_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("docker-login")
echo "The following plugins will be enabled: ${PLUGINS_ENABLED[*]-}"

# cfn-env is sourced by the environment hook in builds
# DO NOT PUT SECRETES IN HERE, they will appear in both the cloudwatch and
# build logs, and the agent's log redactor will not be able to redact them.

# We will create it in two steps so that we don't need to go crazy with quoting and escaping. The
# first sets up a helper function, the second populates the default values for some environment
# variables.

# Step 1: Helper function.  Note that we clobber the target file and DO NOT apply variable
# substitution, this is controlled by the double-quoted "EOF".
echo Writing Phase 1/2 for /var/lib/buildkite-agent/cfn-env helper function...
cat <<-"EOF" >/var/lib/buildkite-agent/cfn-env
	# The Buildkite agent sets a number of variables such as AWS_DEFAULT_REGION to fixed values which
	# are determined at AMI-build-time.  However, sometimes a user might want to override such variables
	# using an env: block in their pipeline.yml.  This little helper is sets the environment variables
	# buildkite-agent and plugins expect, except if a user want to override them, for example to do a
	# deployment to a region other than where the Buildkite agent lives.
	function set_unless_present() {
	    local target=$1
	    local value=$2

	    if [[ -v "${target}" ]]; then
	        echo "^^^ +++"
	        echo "⚠️ ${target} already set, NOT overriding! (current value \"${!target}\" set by Buildkite step env configuration, or inherited from the buildkite-agent process environment)"
	    else
	        echo "export ${target}=\"${value}\""
	        declare -gx "${target}=${value}"
	    fi
	}

	function set_always() {
	    local target=$1
	    local value=$2

	    echo "export ${target}=\"${value}\""
	    declare -gx "${target}=${value}"
	}
EOF

# Step 2: Populate the default variable values.  This time, we append to the file, and allow
# variable substitution.
echo Writing Phase 2/2 for /var/lib/buildkite-agent/cfn-env helper function...
cat <<EOF >>/var/lib/buildkite-agent/cfn-env

set_always         "BUILDKITE_AGENTS_PER_INSTANCE" "$BUILDKITE_AGENTS_PER_INSTANCE"

# also set via /etc/systemd/system/buildkite-agent.service.d/environment.conf
set_always         "BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB" "$BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB"
set_always         "BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL" "$BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL"
set_always         "BUILDKITE_PURGE_BUILDS_ON_DISK_FULL" "$BUILDKITE_PURGE_BUILDS_ON_DISK_FULL"
set_always         "BUILDKITE_ECR_POLICY" "${BUILDKITE_ECR_POLICY:-none}"
set_always         "ECR_CREDENTIAL_HELPER_ENABLED" "$ECR_CREDENTIAL_HELPER_ENABLED"
set_always         "BUILDKITE_SECRETS_BUCKET" "$BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_SECRETS_BUCKET_REGION" "$BUILDKITE_SECRETS_BUCKET_REGION"
set_always         "BUILDKITE_STACK_NAME" "$BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_USERNS_REMAP" "$DOCKER_USERNS_REMAP"
set_always         "ENABLE_PRE_EXIT_DISK_CLEANUP" "$ENABLE_PRE_EXIT_DISK_CLEANUP"
set_always         "DOCKER_PRUNE_UNTIL" "$DOCKER_PRUNE_UNTIL"
set_always         "DOCKER_BUILDER_PRUNE_ENABLED" "$DOCKER_BUILDER_PRUNE_ENABLED"
set_always         "DOCKER_VERSION" "$DOCKER_VERSION"
set_always         "PLUGINS_ENABLED" "${PLUGINS_ENABLED[*]-}"
set_always         "BUILDKITE_ARTIFACTS_BUCKET" "$BUILDKITE_ARTIFACTS_BUCKET"
set_always         "BUILDKITE_S3_DEFAULT_REGION" "$BUILDKITE_S3_DEFAULT_REGION"
set_always         "BUILDKITE_S3_ACL" "$BUILDKITE_S3_ACL"
set_unless_present "AWS_DEFAULT_REGION" "$AWS_REGION"
set_unless_present "AWS_REGION" "$AWS_REGION"
EOF

# We warned about not putting secrets in this file
echo Wrote to /var/lib/buildkite-agent/cfn-env:
cat /var/lib/buildkite-agent/cfn-env
echo

if [[ "${BUILDKITE_AGENT_RELEASE}" == "edge" ]]; then
  echo Downloading buildkite-agent edge...
  curl -Lsf -o /usr/bin/buildkite-agent-edge \
    "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-${ARCH}"
  chmod +x /usr/bin/buildkite-agent-edge
  buildkite-agent-edge --version
else
  echo Not using buildkite-agent edge.
fi

if [[ "${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" != "" ]]; then
  echo "buildkite-agent ALL=NOPASSWD: ${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" \
    >/etc/sudoers.d/buildkite-agent-additional
  chmod 440 /etc/sudoers.d/buildkite-agent-additional

  echo Wrote to /etc/sudoers.d/buildkite-agent-additional...
  cat /etc/sudoers.d/buildkite-agent-additional
else
  echo No additional sudo permissions.
fi

# Choose the right agent binary
ln -sf "/usr/bin/buildkite-agent-$BUILDKITE_AGENT_RELEASE" /usr/bin/buildkite-agent

agent_metadata=(
  "queue=${BUILDKITE_QUEUE}"
  "docker=${DOCKER_VERSION}"
  "stack=${BUILDKITE_STACK_NAME}"
  "buildkite-aws-stack=${BUILDKITE_STACK_VERSION}"
  "stack-deployed-by=${BUILDKITE_STACK_DEPLOYED_BY}"
)

echo "Initial agent metadata: ${agent_metadata[*]-}"
if [[ -n "${BUILDKITE_AGENT_TAGS:-}" ]]; then
  IFS=',' read -r -a extra_agent_metadata <<<"${BUILDKITE_AGENT_TAGS:-}"
  agent_metadata=("${agent_metadata[@]}" "${extra_agent_metadata[@]}")
fi
echo "Agent metadata after splitting commas: ${agent_metadata[*]-}"

seed_git_mirrors_from_bundles() {
  local bundle_bucket_path
  local list_output
  local list_status
  local bundle_count
  local temp_dir
  local aws_max_attempts
  local -a aws_s3_args

  # Keep bundle seeding from blocking bootstrap when S3 is unreachable.
  aws_max_attempts=2
  aws_s3_args=(
    --cli-connect-timeout 10
    --cli-read-timeout 30
  )

  if [[ "${BUILDKITE_AGENT_ENABLE_GIT_MIRRORS:-false}" != "true" ]]; then
    return 0
  fi

  if [[ -z "${BUILDKITE_GIT_MIRROR_BUNDLE_BUCKET:-}" ]]; then
    echo No git mirror bundle bucket configured.
    return 0
  fi

  bundle_bucket_path="s3://${BUILDKITE_GIT_MIRROR_BUNDLE_BUCKET}/git-mirror-bundles/"
  temp_dir=$(mktemp -d \
    "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}/.bundle-seed.XXXXXX")

  echo "Seeding git mirrors from ${bundle_bucket_path}..."

  set +e
  list_output=$(AWS_MAX_ATTEMPTS="${aws_max_attempts}" \
    aws "${aws_s3_args[@]}" s3 ls "${bundle_bucket_path}" --recursive 2>&1)
  list_status=$?
  set -e

  if [[ ${list_status} -ne 0 ]]; then
    echo "WARNING: Failed to list git mirror bundles from ${bundle_bucket_path}: ${list_output}"
    rm -rf "${temp_dir}"
    return 0
  fi

  bundle_count=0
  while read -r _ _ _ bundle_key; do
    local bundle_name
    local bundle_path
    local bundle_uri
    local mirror_path
    local mirror_name

    [[ -n "${bundle_key:-}" ]] || continue
    [[ "${bundle_key}" == *.bundle ]] || continue

    bundle_count=$((bundle_count + 1))
    bundle_name=$(basename "${bundle_key}")
    mirror_name=${bundle_name%.bundle}
    mirror_path="${BUILDKITE_AGENT_GIT_MIRRORS_PATH}/${mirror_name}"
    bundle_uri="s3://${BUILDKITE_GIT_MIRROR_BUNDLE_BUCKET}/${bundle_key}"
    bundle_path="${temp_dir}/${bundle_name}"

    if [[ -e "${mirror_path}" ]]; then
      echo "Git mirror ${mirror_path} already exists, skipping ${bundle_uri}."
      continue
    fi

    echo "Seeding git mirror ${mirror_path} from ${bundle_uri}..."
    if ! AWS_MAX_ATTEMPTS="${aws_max_attempts}" \
      aws "${aws_s3_args[@]}" s3 cp "${bundle_uri}" "${bundle_path}"; then
      echo "WARNING: Failed to download git mirror bundle ${bundle_uri}."
      rm -f "${bundle_path}"
      continue
    fi

    if ! GIT_CURL_VERBOSE=0 GIT_TERMINAL_PROMPT=0 GIT_CONFIG_PARAMETERS="'core.fsck=false' 'gc.auto=0'" GIT_LFS_SKIP_SMUDGE=1 git clone --bare --quiet "${bundle_path}" "${mirror_path}"; then
      echo "WARNING: Failed to seed git mirror ${mirror_path} from ${bundle_uri}."
      rm -f "${bundle_path}"
      rm -rf "${mirror_path}"
      continue
    fi

    # Set the real remote URL so the agent doesn't detect a URL change
    # (which triggers an expensive fsck + gc while holding the mirror lock).
    local url_sidecar_uri="s3://${BUILDKITE_GIT_MIRROR_BUNDLE_BUCKET}/git-mirror-bundles/${mirror_name}.url"
    local url_sidecar_path="${temp_dir}/${mirror_name}.url"
    if AWS_MAX_ATTEMPTS="${aws_max_attempts}" \
      aws "${aws_s3_args[@]}" s3 cp "${url_sidecar_uri}" "${url_sidecar_path}" 2>/dev/null; then
      local real_url
      real_url=$(cat "${url_sidecar_path}")
      if [[ -n "${real_url}" ]]; then
        echo "Setting mirror origin to ${real_url}"
        git --git-dir "${mirror_path}" remote set-url origin "${real_url}"
      fi
      rm -f "${url_sidecar_path}"
    else
      echo "WARNING: No .url sidecar found for ${mirror_name}, mirror origin will be the bundle path."
    fi

    if ! chown -R buildkite-agent: "${mirror_path}"; then
      echo "WARNING: Failed to set ownership for seeded git mirror ${mirror_path}."
      rm -f "${bundle_path}"
      rm -rf "${mirror_path}"
      continue
    fi

    rm -f "${bundle_path}"
  done <<<"${list_output}"

  rm -rf "${temp_dir}"

  if [[ ${bundle_count} -eq 0 ]]; then
    echo "No git mirror bundles found in ${bundle_bucket_path}."
  fi
}

# Enable git-mirrors if a git mirrors path is provided
BUILDKITE_AGENT_GIT_MIRRORS_PATH=""
if [[ "${BUILDKITE_AGENT_ENABLE_GIT_MIRRORS:-false}" == "true" ]]; then
  BUILDKITE_AGENT_GIT_MIRRORS_PATH=/var/lib/buildkite-agent/git-mirrors
  echo "git-mirrors enabled at $BUILDKITE_AGENT_GIT_MIRRORS_PATH"
  mkdir -p "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"

  if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]]; then
    echo Mounting git-mirrors to instance storage...

    EPHEMERAL_GIT_MIRRORS_PATH="/mnt/ephemeral/git-mirrors"
    echo "Creating ephemeral git-mirrors direcotry at $EPHEMERAL_GIT_MIRRORS_PATH"
    mkdir -p "${EPHEMERAL_GIT_MIRRORS_PATH}"

    echo Bind mounting ephemeral git-mirror directory to git-mirrors path...
    mount -o bind "${EPHEMERAL_GIT_MIRRORS_PATH}" "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"

    echo Writing bind mount to fstab...
    echo "${EPHEMERAL_GIT_MIRRORS_PATH} ${BUILDKITE_AGENT_GIT_MIRRORS_PATH} none defaults,bind 0 0" >>/etc/fstab

    echo fstab is now:
    cat /etc/fstab
    echo
  else
    echo Not mounting git-mirrors to instance storage as instance storage is disabled.
  fi

  echo Setting ownership of git-mirrors directory to buildkite-agent...
  chown buildkite-agent: "$BUILDKITE_AGENT_GIT_MIRRORS_PATH"

  seed_git_mirrors_from_bundles
else
  echo git-mirrors disabled.
fi
echo "BUILDKITE_AGENT_GIT_MIRRORS_PATH is $BUILDKITE_AGENT_GIT_MIRRORS_PATH"

BUILDKITE_AGENT_BUILD_PATH="/var/lib/buildkite-agent/builds"
mkdir -p "${BUILDKITE_AGENT_BUILD_PATH}"
if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]]; then
  echo Bind mounting build path to instance storage...

  EPHEMERAL_BUILD_PATH="/mnt/ephemeral/builds"
  mkdir -p "${EPHEMERAL_BUILD_PATH}"

  mount -o bind "${EPHEMERAL_BUILD_PATH}" "${BUILDKITE_AGENT_BUILD_PATH}"
  echo "${EPHEMERAL_BUILD_PATH} ${BUILDKITE_AGENT_BUILD_PATH} none defaults,bind 0 0" >>/etc/fstab

  echo fstab is now:
  cat /etc/fstab
else
  echo Not mounting build path to instance storage as instance storage is disabled.
fi

echo Setting ownership of build path to buildkite-agent.
chown buildkite-agent: "$BUILDKITE_AGENT_BUILD_PATH"

# Either you can have timestamp-lines xor ansi-timestamps.
# There's no technical reason you can't have both, it's a pragmatic decision to
# simplify the avaliable parameters on the stack
if [[ ${BUILDKITE_AGENT_TIMESTAMP_LINES:-"false"} == "true" ]]; then
  BUILDKITE_AGENT_TIMESTAMPS_LINES="true"
  BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS="true"
else
  BUILDKITE_AGENT_TIMESTAMPS_LINES="false"
  BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS="false"
fi

echo Setting \$BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS to \$BUILDKITE_AGENT_TIMESTAMP_LINES
echo "BUILDKITE_AGENT_TIMESTAMP_LINES is $BUILDKITE_AGENT_TIMESTAMPS_LINES"
echo "BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS is $BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS"

echo "Setting \$BUILDKITE_AGENT_TOKEN from SSM Parameter $BUILDKITE_AGENT_TOKEN_PATH"
BUILDKITE_AGENT_TOKEN="$(
  aws ssm get-parameter \
    --name "$BUILDKITE_AGENT_TOKEN_PATH" \
    --with-decryption \
    --query Parameter.Value \
    --output text
)"

# DO NOT write this file to logs. It contains secrets.
cat <<EOF >/etc/buildkite-agent/buildkite-agent.cfg
name="${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%spawn"
token="${BUILDKITE_AGENT_TOKEN}"
tags=$(
  IFS=,
  echo "${agent_metadata[*]}"
)
endpoint=${BUILDKITE_AGENT_ENDPOINT:-"https://agent-edge.buildkite.com/v3"}
tags-from-ec2-meta-data=true
no-ansi-timestamps=${BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS}
timestamp-lines=${BUILDKITE_AGENT_TIMESTAMP_LINES}
hooks-path=/etc/buildkite-agent/hooks
build-path=${BUILDKITE_AGENT_BUILD_PATH}
plugins-path=/var/lib/buildkite-agent/plugins
git-mirrors-path="${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"
experiment="${BUILDKITE_AGENT_EXPERIMENTS}"
priority=%n
spawn=${BUILDKITE_AGENTS_PER_INSTANCE}
no-color=true
disconnect-after-idle-timeout=${BUILDKITE_SCALE_IN_IDLE_PERIOD}
disconnect-after-job=${BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB}
disconnect-after-uptime=${BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME}
tracing-backend=${BUILDKITE_AGENT_TRACING_BACKEND}
cancel-grace-period=${BUILDKITE_AGENT_CANCEL_GRACE_PERIOD}
signal-grace-period-seconds=${BUILDKITE_AGENT_SIGNAL_GRACE_PERIOD_SECONDS}
signing-aws-kms-key=${BUILDKITE_AGENT_SIGNING_KMS_KEY}
verification-failure-behavior=${BUILDKITE_AGENT_JOB_VERIFICATION_NO_SIGNATURE_BEHAVIOR}
EOF

if [[ -n "$BUILDKITE_AGENT_SIGNING_KEY_PATH" ]]; then
  echo "Fetching signing key from ssm: $BUILDKITE_AGENT_SIGNING_KEY_PATH..."

  keyfile=/etc/buildkite-agent/signing-key.json

  aws ssm get-parameter \
    --name "$BUILDKITE_AGENT_SIGNING_KEY_PATH" \
    --with-decryption \
    --query Parameter.Value \
    --output text >"$keyfile"

  echo "Setting ownership and permissions for $keyfile..."
  chown root:buildkite-agent "$keyfile"
  chmod 640 "$keyfile"

  echo "signing-jwks-file=$keyfile" >>/etc/buildkite-agent/buildkite-agent.cfg
fi

if [[ -n "$BUILDKITE_AGENT_SIGNING_KEY_ID" ]]; then
  echo "signing-jwks-key-id=$BUILDKITE_AGENT_SIGNING_KEY_ID" >>/etc/buildkite-agent/buildkite-agent.cfg
fi

if [[ -n "$BUILDKITE_AGENT_VERIFICATION_KEY_PATH" ]]; then
  echo "Fetching verification key from ssm: $BUILDKITE_AGENT_VERIFICATION_KEY_PATH..."

  keyfile=/etc/buildkite-agent/verification-key.json

  aws ssm get-parameter \
    --name "$BUILDKITE_AGENT_VERIFICATION_KEY_PATH" \
    --with-decryption \
    --query Parameter.Value \
    --output text >"$keyfile"

  echo "Setting ownership and permissions for $keyfile..."
  chown root:buildkite-agent "$keyfile"
  chmod 640 "$keyfile"

  echo "verification-jwks-file=$keyfile" >>/etc/buildkite-agent/buildkite-agent.cfg
fi

if [[ "${BUILDKITE_ENV_FILE_URL}" != "" ]]; then
  echo "Fetching env file from ${BUILDKITE_ENV_FILE_URL}..."
  /usr/local/bin/bk-fetch.sh "${BUILDKITE_ENV_FILE_URL}" /var/lib/buildkite-agent/env
else
  echo No env file to fetch.
fi

echo Setting ownership of /etc/buildkite-agent/buildkite-agent.cfg to buildkite-agent...
chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

if [[ -n "$BUILDKITE_AUTHORIZED_USERS_URL" ]]; then
  echo Writing authorized user fetching script...
  cat <<-EOF | tee /usr/local/bin/refresh_authorized_keys
		#!/usr/bin/env bash
		/usr/local/bin/bk-fetch.sh "$BUILDKITE_AUTHORIZED_USERS_URL" /tmp/authorized_keys
		mv /tmp/authorized_keys /home/ec2-user/.ssh/authorized_keys
		chmod 600 /home/ec2-user/.ssh/authorized_keys
		chown ec2-user: /home/ec2-user/.ssh/authorized_keys
	EOF

  echo Setting ownership of /usr/local/bin/refresh_authorized_keys to root...
  chmod +x /usr/local/bin/refresh_authorized_keys

  echo Running authorized user fetching script...
  /usr/local/bin/refresh_authorized_keys

  echo Enabling authorized user fetching timer...
  systemctl enable refresh_authorized_keys.timer
else
  echo No authorized users to fetch.
fi

echo Installing git-lfs for buildkite-agent user...
su buildkite-agent -l -c 'git lfs install'

if [[ -n "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" ]]; then
  echo "Running bootstrap script from $BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT..."
  /usr/local/bin/bk-fetch.sh "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" /tmp/elastic_bootstrap
  bash </tmp/elastic_bootstrap
  rm /tmp/elastic_bootstrap
else
  echo No bootstrap script to run.
fi

echo Writing lifecycled configuration...
cat <<EOF | tee /etc/lifecycled
AWS_REGION=$AWS_REGION
LIFECYCLED_HANDLER=/usr/local/bin/stop-agent-gracefully
LIFECYCLED_CLOUDWATCH_GROUP=/buildkite/lifecycled
EOF

echo Starting lifecycled...
systemctl enable --now lifecycled.service

echo Waiting for docker to start...
check_docker() {
  if ! docker ps >/dev/null; then
    echo Failed to contact docker.
    return 1
  fi
}

next_wait_time=0
until check_docker || [[ $next_wait_time -eq 5 ]]; do
  sleep $((next_wait_time++))
done

# Configure resource limits if enabled
if [[ "${ENABLE_RESOURCE_LIMITS:-false}" == "true" ]]; then
  echo "Configuring systemd resource limits for Buildkite agent..."

  MEMORY_HIGH="${RESOURCE_LIMITS_MEMORY_HIGH:-90%}"
  MEMORY_MAX="${RESOURCE_LIMITS_MEMORY_MAX:-90%}"
  MEMORY_SWAP_MAX="${RESOURCE_LIMITS_MEMORY_SWAP_MAX:-90%}"
  CPU_WEIGHT="${RESOURCE_LIMITS_CPU_WEIGHT:-100}"
  CPU_QUOTA="${RESOURCE_LIMITS_CPU_QUOTA:-90%}"
  IO_WEIGHT="${RESOURCE_LIMITS_IO_WEIGHT:-80}"

  echo "Resource limits configuration:"
  echo "  MemoryHigh: ${MEMORY_HIGH}"
  echo "  MemoryMax: ${MEMORY_MAX}"
  echo "  MemorySwapMax: ${MEMORY_SWAP_MAX}"
  echo "  CPUWeight: ${CPU_WEIGHT}"
  echo "  CPUQuota: ${CPU_QUOTA}"
  echo "  IOWeight: ${IO_WEIGHT}"

  cat >/etc/systemd/system/buildkite-agent.slice <<EOL
[Unit]
Description=Buildkite Agent Slice
Before=slices.target

[Slice]
MemoryHigh=${MEMORY_HIGH}
MemoryMax=${MEMORY_MAX}
MemorySwapMax=${MEMORY_SWAP_MAX}
CPUWeight=${CPU_WEIGHT}
CPUQuota=${CPU_QUOTA}
IOWeight=${IO_WEIGHT}
EOL

  mkdir -p /etc/systemd/system/buildkite-agent.service.d
  cat >/etc/systemd/system/buildkite-agent.service.d/10-resource-limits.conf <<'EOL'
[Service]
Slice=buildkite-agent.slice
IgnoreOnIsolate=yes
EOL

  chmod 644 /etc/systemd/system/buildkite-agent.slice
  chmod 644 /etc/systemd/system/buildkite-agent.service.d/10-resource-limits.conf

  systemctl daemon-reload
  echo "Resource limits configured successfully"
fi

echo "Waited $next_wait_time times for docker to start. We will exit if it still has not started."
check_docker

echo Writing buildkite-agent systemd environment override...
# also set in /var/lib/buildkite-agent/cfn-env so that it's shown in the job logs
mkdir -p /etc/systemd/system/buildkite-agent.service.d
cat <<EOF | tee /etc/systemd/system/buildkite-agent.service.d/environment.conf
[Service]
Environment="BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=${BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB}"
EOF

echo Reloading systemctl services...
systemctl daemon-reload

echo Starting buildkite-agent...
systemctl enable --now buildkite-agent

echo Configuring CloudWatch agent log retention...
if [[ -n "${EC2_LOG_RETENTION_DAYS:-}" && "${ENABLE_EC2_LOG_RETENTION_POLICY:-false}" == "true" ]]; then
  echo "Setting CloudWatch EC2 log retention to ${EC2_LOG_RETENTION_DAYS} days"
  echo "WARNING: This will delete EC2 logs older than ${EC2_LOG_RETENTION_DAYS} days from existing log groups"

  # Update the CloudWatch agent config with the retention value
  CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
  if [[ -f "$CONFIG_FILE" ]]; then
    # Add retention_in_days to all collect_list items using jq
    jq --arg retention "$EC2_LOG_RETENTION_DAYS" '
      .logs.logs_collected.files.collect_list |= map(. + {"retention_in_days": ($retention | tonumber)})
    ' "$CONFIG_FILE" >/tmp/cloudwatch_config.json && mv /tmp/cloudwatch_config.json "$CONFIG_FILE"

    # Restart CloudWatch agent to pick up the new configuration
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "file:$CONFIG_FILE" || echo "Warning: Failed to restart CloudWatch agent"
    echo "CloudWatch agent configuration updated and restarted"
  else
    echo "Warning: CloudWatch agent config file not found at $CONFIG_FILE"
  fi
elif [[ -n "${EC2_LOG_RETENTION_DAYS:-}" ]]; then
  echo "EC2 log retention set to ${EC2_LOG_RETENTION_DAYS} days but EnableEC2LogRetentionPolicy is false"
  echo "Skipping EC2 log retention configuration to protect existing logs"
else
  echo "EC2 log retention not set, using CloudWatch agent defaults (never expire)"
fi

if [[ "${BUILDKITE_STACK_DEPLOYED_BY:-}" == "cloudformation" ]]; then
  echo Signaling success to CloudFormation...
  # This will fail if the stack has already completed, for instance if there is a min size
  # of 1 and this is the 2nd instance. This is ok, so we just ignore the error
  cfn-signal \
    --region "$AWS_REGION" \
    --stack "$BUILDKITE_STACK_NAME" \
    --resource "AgentAutoScaleGroup" \
    --exit-code 0 || echo Signal failed
else
  echo "Skipping cfn-signal (not deployed by CloudFormation)"
fi

# Record bootstrap as complete (this should be the last step in this file)
echo "Completed" >"$STATUS_FILE"
