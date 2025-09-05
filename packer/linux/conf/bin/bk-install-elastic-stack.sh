#!/usr/bin/env bash

set -Eeuo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

# Function to clean up background processes on exit
cleanup_background_processes() {
  echo "Cleaning up remaining background processes..."

  for process_name in "${!background_processes[@]}"; do
    local process_info="${background_processes[$process_name]}"
    local pid="${process_info%%:*}"
    local critical="${process_info##*:}"

    if kill -0 "$pid" 2>/dev/null; then
      echo "Terminating $process_name (PID: $pid)..."

      # Try graceful termination first
      kill -TERM "$pid" 2>/dev/null || true

      # Wait a moment for graceful shutdown
      sleep 2

      # Force kill if still running
      if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing $process_name (PID: $pid)"
        kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
  done

  # Clean up temporary files
  rm -f /tmp/buildkite_agent_token 2>/dev/null || true
  echo "Background process cleanup completed"
}

on_error() {
  local exit_code="$?"
  local error_line="$1"

  echo "${BASH_SOURCE[0]} errored with exit code ${exit_code} on line ${error_line}."

  # Clean up background processes before failing
  cleanup_background_processes

  if [[ $exit_code != 0 ]]; then
    if ! aws autoscaling set-instance-health \
      --instance-id "$INSTANCE_ID" \
      --health-status Unhealthy; then
      echo Failed to set instance health to unhealthy.
    fi
  fi

  cfn-signal \
    --region "$AWS_REGION" \
    --stack "$BUILDKITE_STACK_NAME" \
    --reason "Error on line $error_line: $(tail -n 1 /var/log/elastic-stack.log)" \
    --resource "AgentAutoScaleGroup" \
    --exit-code "$exit_code"

  exit "$exit_code"
}

trap 'on_error $LINENO' ERR

on_exit() {
  echo "${BASH_SOURCE[0]} completed successfully."

  # Clean up any remaining background processes on successful exit
  cleanup_background_processes
}

trap '[[ $? = 0 ]] && on_exit' EXIT

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting ${BASH_SOURCE[0]}..."

# This needs to happen first so that the error reporting works
token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --fail --silent --show-error --location http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $token" --fail --silent --show-error --location http://169.254.169.254/latest/meta-data/instance-id)
echo "Detected INSTANCE_ID=$INSTANCE_ID"

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

# Network readiness check function
wait_for_network() {
  echo "Checking network readiness..."
  local timeout=30
  local start_time
  start_time=$(date +%s)
  local check_count=0

  while true; do
    check_count=$((check_count + 1))

    # Test multiple network endpoints to ensure robust connectivity
    if curl -s --connect-timeout 3 --max-time 5 http://169.254.169.254/latest/meta-data/ >/dev/null 2>&1 \
      && curl -s --connect-timeout 3 --max-time 5 https://aws.amazon.com >/dev/null 2>&1; then
      echo "Network is ready (verified after ${check_count} attempts)"
      return 0
    fi

    local current_time
    current_time=$(date +%s)
    if [ $((current_time - start_time)) -gt "$timeout" ]; then
      echo "WARNING: Network not fully ready after ${timeout}s and ${check_count} attempts"
      echo "Proceeding with degraded network conditions - some operations may retry"
      return 0
    fi

    sleep 1
  done
}

# Enhanced function to fetch environment file with error handling and retry logic
fetch_env_file() {
  echo "Starting environment file fetch..."

  # Wait for network readiness
  wait_for_network

  if [[ "${BUILDKITE_ENV_FILE_URL}" != "" ]]; then
    echo "Fetching env file from ${BUILDKITE_ENV_FILE_URL}..."

    local max_retries=3
    local retry_delay=2
    local attempt=1

    while [ $attempt -le $max_retries ]; do
      echo "Environment file fetch attempt $attempt of $max_retries..."

      if /usr/local/bin/bk-fetch.sh "${BUILDKITE_ENV_FILE_URL}" /var/lib/buildkite-agent/env; then
        echo "Environment file fetched successfully"
        break
      else
        echo "Warning: Attempt $attempt failed to fetch environment file"
        if [ $attempt -lt $max_retries ]; then
          echo "Retrying in ${retry_delay} seconds..."
          sleep $retry_delay
          retry_delay=$((retry_delay * 2)) # exponential backoff
        else
          echo "Warning: All attempts failed, creating empty environment file"
          touch /var/lib/buildkite-agent/env
        fi
      fi
      attempt=$((attempt + 1))
    done
  else
    echo "No env file URL configured, creating empty environment file"
    touch /var/lib/buildkite-agent/env
  fi

  # Ensure proper ownership
  chown buildkite-agent: /var/lib/buildkite-agent/env 2>/dev/null || true
  echo "Environment file fetch completed"
}

# Enhanced function to fetch authorized users in background with retry logic
fetch_authorized_users() {
  echo "Starting authorized users fetch..."

  # Wait for network readiness
  wait_for_network

  if [[ -n "$BUILDKITE_AUTHORIZED_USERS_URL" ]]; then
    echo "Fetching authorized users from ${BUILDKITE_AUTHORIZED_USERS_URL}..."

    # Create the refresh script with retry logic
    cat <<-EOF >/usr/local/bin/refresh_authorized_keys
#!/bin/bash
set -euo pipefail

MAX_RETRIES=3
RETRY_DELAY=2
ATTEMPT=1

while [ \$ATTEMPT -le \$MAX_RETRIES ]; do
  echo "Authorized users fetch attempt \$ATTEMPT of \$MAX_RETRIES..."

  if /usr/local/bin/bk-fetch.sh "$BUILDKITE_AUTHORIZED_USERS_URL" /tmp/authorized_keys; then
    mv /tmp/authorized_keys /home/ec2-user/.ssh/authorized_keys
    chmod 600 /home/ec2-user/.ssh/authorized_keys
    chown ec2-user: /home/ec2-user/.ssh/authorized_keys
    echo "Authorized users updated successfully"
    exit 0
  else
    echo "Warning: Attempt \$ATTEMPT failed to fetch authorized users"
    if [ \$ATTEMPT -lt \$MAX_RETRIES ]; then
      echo "Retrying in \$RETRY_DELAY seconds..."
      sleep \$RETRY_DELAY
      RETRY_DELAY=\$((RETRY_DELAY * 2))  # exponential backoff
    fi
  fi
  ATTEMPT=\$((ATTEMPT + 1))
done

echo "ERROR: Failed to fetch authorized users after \$MAX_RETRIES attempts"
exit 1
EOF
    chmod +x /usr/local/bin/refresh_authorized_keys

    # Perform initial fetch with retry logic
    local max_retries=3
    local retry_delay=2
    local attempt=1

    while [ $attempt -le $max_retries ]; do
      echo "Authorized users initial fetch attempt $attempt of $max_retries..."

      if /usr/local/bin/refresh_authorized_keys; then
        echo "Authorized users configured successfully"
        break
      else
        echo "Warning: Attempt $attempt failed to configure authorized users"
        if [ $attempt -lt $max_retries ]; then
          echo "Retrying in ${retry_delay} seconds..."
          sleep $retry_delay
          retry_delay=$((retry_delay * 2)) # exponential backoff
        else
          echo "Warning: All attempts failed for authorized users configuration"
        fi
      fi
      attempt=$((attempt + 1))
    done

    # Enable the timer for periodic updates
    systemctl enable refresh_authorized_keys.timer 2>/dev/null \
      || echo "Warning: Failed to enable refresh_authorized_keys timer"
  else
    echo "No authorized users URL configured"
  fi
  echo "Authorized users fetch completed"
}

# Enhanced function to run bootstrap script with proper error handling
run_bootstrap_script() {
  echo "Processing bootstrap script..."
  if [[ -n "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" ]]; then
    echo "Fetching and running bootstrap script from $BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT..."

    if /usr/local/bin/bk-fetch.sh "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" /tmp/elastic_bootstrap; then
      echo "Bootstrap script fetched successfully, executing..."
      if bash </tmp/elastic_bootstrap; then
        echo "Bootstrap script completed successfully"
      else
        local exit_code=$?
        echo "ERROR: Bootstrap script execution failed with exit code $exit_code"
        rm -f /tmp/elastic_bootstrap
        return $exit_code
      fi
      rm -f /tmp/elastic_bootstrap
    else
      echo "ERROR: Failed to fetch bootstrap script from $BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT"
      return 1
    fi
  else
    echo "No bootstrap script configured"
  fi
  echo "Bootstrap script processing completed"
}

# Enhanced function to configure CloudWatch agent log retention
configure_cloudwatch_retention() {
  echo "Configuring CloudWatch agent log retention in background..."

  if [[ -n "${EC2_LOG_RETENTION_DAYS:-}" && "${ENABLE_EC2_LOG_RETENTION_POLICY:-false}" == "true" ]]; then
    echo "Setting CloudWatch EC2 log retention to ${EC2_LOG_RETENTION_DAYS} days"
    echo "WARNING: This will delete EC2 logs older than ${EC2_LOG_RETENTION_DAYS} days from existing log groups"

    # Update the CloudWatch agent config with the retention value
    local CONFIG_FILE="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
    if [[ -f "$CONFIG_FILE" ]]; then
      # Add retention_in_days to all collect_list items using jq
      if jq --arg retention "$EC2_LOG_RETENTION_DAYS" '
        .logs.logs_collected.files.collect_list |= map(. + {"retention_in_days": ($retention | tonumber)})
      ' "$CONFIG_FILE" >/tmp/cloudwatch_config.json && mv /tmp/cloudwatch_config.json "$CONFIG_FILE"; then

        # Restart CloudWatch agent to pick up the new configuration
        if /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c "file:$CONFIG_FILE"; then
          echo "CloudWatch agent configuration updated and restarted successfully"
        else
          echo "Warning: Failed to restart CloudWatch agent"
        fi
      else
        echo "Error: Failed to update CloudWatch agent configuration file"
      fi
    else
      echo "Warning: CloudWatch agent config file not found at $CONFIG_FILE"
    fi
  elif [[ -n "${EC2_LOG_RETENTION_DAYS:-}" ]]; then
    echo "EC2 log retention set to ${EC2_LOG_RETENTION_DAYS} days but EnableEC2LogRetentionPolicy is false"
    echo "Skipping EC2 log retention configuration to protect existing logs"
  else
    echo "EC2 log retention not set, using CloudWatch agent defaults (never expire)"
  fi

  echo "CloudWatch agent configuration completed"
}

# Enhanced function to fetch Buildkite agent token with retry logic
fetch_agent_token() {
  local token_file="/tmp/buildkite_agent_token"
  echo "Fetching Buildkite agent token from SSM Parameter $BUILDKITE_AGENT_TOKEN_PATH..."
  local max_retries=3
  local retry_delay=2
  local attempt=1

  while [ $attempt -le $max_retries ]; do
    echo "SSM fetch attempt $attempt of $max_retries..."

    if BUILDKITE_AGENT_TOKEN=$(aws ssm get-parameter \
      --name "$BUILDKITE_AGENT_TOKEN_PATH" \
      --with-decryption \
      --query Parameter.Value \
      --output text 2>/dev/null); then

      # Validate token is not empty
      if [[ -n "$BUILDKITE_AGENT_TOKEN" && "$BUILDKITE_AGENT_TOKEN" != "None" ]]; then
        echo "Buildkite agent token retrieved successfully"
        # Write token to file for main process to read
        echo "$BUILDKITE_AGENT_TOKEN" >"$token_file"
        chmod 600 "$token_file"
        echo "Token written to secure temporary file"
        return 0
      else
        echo "WARNING: Retrieved empty or invalid token from SSM"
      fi
    else
      local exit_code=$?
      case $exit_code in
      255 | 254) echo "WARNING: SSM parameter not found or access denied" ;;
      *) echo "WARNING: SSM API call failed with exit code $exit_code" ;;
      esac
    fi

    if [ $attempt -lt $max_retries ]; then
      echo "Retrying in ${retry_delay} seconds..."
      sleep $retry_delay
      retry_delay=$((retry_delay * 2)) # exponential backoff: 2s, 4s
    fi

    attempt=$((attempt + 1))
  done

  echo "ERROR: Failed to retrieve Buildkite agent token after $max_retries attempts"
  echo "Please verify:"
  echo "  1. SSM parameter '$BUILDKITE_AGENT_TOKEN_PATH' exists"
  echo "  2. Instance has proper IAM permissions for SSM:GetParameter"
  echo "  3. Network connectivity to AWS SSM service"
  return 1
}

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
set_always         "BUILDKITE_SECRETS_BUCKET" "$BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_SECRETS_BUCKET_REGION" "$BUILDKITE_SECRETS_BUCKET_REGION"
set_always         "BUILDKITE_STACK_NAME" "$BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_USERNS_REMAP" "$DOCKER_USERNS_REMAP"
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

# Enhanced background process management with error handling and timeout protection
declare -A background_processes

# Function to start a background process with monitoring
start_background_process() {
  local name="$1"
  local function_name="$2"
  local critical="${3:-false}" # Optional: whether process failure should be fatal

  echo "Starting $name in background..."

  # Start the function in a subshell with error handling
  (
    set -euo pipefail
    echo "$name: Process started (PID: $$)"
    $function_name
    echo "$name: Process completed successfully"
  ) &

  local pid=$!
  background_processes["$name"]="$pid:$critical"
  echo "$name started (PID: $pid, critical: $critical)"
}

# Function to wait for a background process with timeout and error handling
wait_for_background_process() {
  local name="$1"
  local timeout="${2:-300}" # Default 5 minute timeout

  if [[ -z "${background_processes[$name]:-}" ]]; then
    echo "ERROR: Background process '$name' was not started"
    return 1
  fi

  local process_info="${background_processes["$name"]}"
  local pid="${process_info%%:*}"
  local critical="${process_info##*:}"

  echo "Waiting for $name (PID: $pid, timeout: ${timeout}s, critical: $critical)..."

  local start_time
  start_time=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    local current_time
    current_time=$(date +%s)
    if [ $((current_time - start_time)) -gt "$timeout" ]; then
      echo "WARNING: $name (PID: $pid) exceeded timeout of ${timeout}s"

      # Try to terminate gracefully first
      kill -TERM "$pid" 2>/dev/null || true
      sleep 5

      # Force kill if still running
      if kill -0 "$pid" 2>/dev/null; then
        echo "Force killing $name (PID: $pid)"
        kill -KILL "$pid" 2>/dev/null || true
      fi

      if [[ "$critical" == "true" ]]; then
        echo "ERROR: Critical process '$name' failed due to timeout"
        return 1
      else
        echo "WARNING: Non-critical process '$name' timed out - continuing"
        return 0
      fi
    fi
    sleep 1
  done

  # Check exit status
  if wait "$pid"; then
    echo "$name completed successfully"
    unset "background_processes[$name]"
    return 0
  else
    local exit_code=$?
    echo "ERROR: $name failed with exit code $exit_code"

    if [[ "$critical" == "true" ]]; then
      echo "ERROR: Critical process '$name' failed - this will cause bootstrap to fail"
      return $exit_code
    else
      echo "WARNING: Non-critical process '$name' failed - continuing with degraded functionality"
      return 0
    fi
  fi
}

# Function to display status of all background processes
show_background_process_status() {
  echo "Background process status:"

  if [[ ${#background_processes[@]} -eq 0 ]]; then
    echo "  No background processes running"
    return 0
  fi

  for process_name in "${!background_processes[@]}"; do
    local process_info="${background_processes[$process_name]}"
    local pid="${process_info%%:*}"
    local critical="${process_info##*:}"

    if kill -0 "$pid" 2>/dev/null; then
      echo "  $process_name: RUNNING (PID: $pid, critical: $critical)"
    else
      echo "  $process_name: COMPLETED/FAILED (PID: $pid, critical: $critical)"
    fi
  done
}

# Function to check for failed background processes
check_background_process_health() {
  local failed_critical=false
  local failed_processes=()

  for process_name in "${!background_processes[@]}"; do
    local process_info="${background_processes[$process_name]}"
    local pid="${process_info%%:*}"
    local critical="${process_info##*:}"

    if ! kill -0 "$pid" 2>/dev/null; then
      # Process has exited, check if it failed
      if ! wait "$pid" 2>/dev/null; then
        failed_processes+=("$process_name")
        if [[ "$critical" == "true" ]]; then
          failed_critical=true
        fi
      fi
    fi
  done

  if [[ ${#failed_processes[@]} -gt 0 ]]; then
    echo "WARNING: Background processes failed: ${failed_processes[*]}"
    if [[ "$failed_critical" == "true" ]]; then
      echo "ERROR: Critical background processes have failed"
      return 1
    fi
  fi

  return 0
}

# Start background processes with proper monitoring
start_background_process "cloudwatch_config" "configure_cloudwatch_retention" "false"
start_background_process "auth_fetch" "fetch_authorized_users" "false"
start_background_process "token_fetch" "fetch_agent_token" "true"
start_background_process "env_fetch" "fetch_env_file" "true"

# Show initial status
show_background_process_status

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
)

echo "Initial agent metadata: ${agent_metadata[*]-}"
if [[ -n "${BUILDKITE_AGENT_TAGS:-}" ]]; then
  IFS=',' read -r -a extra_agent_metadata <<<"${BUILDKITE_AGENT_TAGS:-}"
  agent_metadata=("${agent_metadata[@]}" "${extra_agent_metadata[@]}")
fi
echo "Agent metadata after splitting commas: ${agent_metadata[*]-}"

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

echo "Waiting for critical background processes to complete..."

# Wait for token fetch (critical - 60 second timeout)
if ! wait_for_background_process "token_fetch" 60; then
  echo "ERROR: Token fetch process failed - cannot proceed without agent token"
  exit 1
fi

# Read token from secure temporary file
token_file="/tmp/buildkite_agent_token"
if [[ -f "$token_file" ]]; then
  BUILDKITE_AGENT_TOKEN=$(cat "$token_file")
  rm -f "$token_file" # Clean up immediately after reading
  echo "Token read from temporary file and file cleaned up"
else
  echo "ERROR: Token file not found at $token_file"
  echo "This indicates the background token retrieval process failed"
  exit 1
fi

if [[ -z "$BUILDKITE_AGENT_TOKEN" ]]; then
  echo "ERROR: BUILDKITE_AGENT_TOKEN is empty after reading from file"
  echo "This indicates a problem with the background token retrieval process"
  exit 1
fi

echo "Buildkite agent token is ready for configuration"

# Wait for environment file fetch (critical - 30 second timeout)
if ! wait_for_background_process "env_fetch" 30; then
  echo "ERROR: Environment file fetch failed - this is required for agent configuration"
  exit 1
fi

# DO NOT write this file to logs. It contains secrets.
cat <<EOF >/etc/buildkite-agent/buildkite-agent.cfg
name="${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%spawn"
token="${BUILDKITE_AGENT_TOKEN}"
tags=$(
  IFS=,
  echo "${agent_metadata[*]}"
)
endpoint=${BUILDKITE_AGENT_ENDPOINT:-"https://agent.buildkite.com/v3"}
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
verification-failure-behavior=${BUILDKITE_AGENT_SIGNING_FAILURE_BEHAVIOR}
EOF

echo Setting ownership of /etc/buildkite-agent/buildkite-agent.cfg to buildkite-agent...
chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

# Note: Authorized users fetch continues in background (non-critical)

echo Installing git-lfs for buildkite-agent user...
su buildkite-agent -l -c 'git lfs install'

# Check background process health before continuing
echo "Checking background process health before bootstrap script..."
if ! check_background_process_health; then
  echo "ERROR: Critical background processes have failed before bootstrap script"
  exit 1
fi

# Execute bootstrap script with enhanced error handling
if ! run_bootstrap_script; then
  echo "ERROR: Bootstrap script execution failed"
  exit 1
fi

echo Writing lifecycled configuration...
cat <<EOF | tee /etc/lifecycled
AWS_REGION=$AWS_REGION
LIFECYCLED_HANDLER=/usr/local/bin/stop-agent-gracefully
LIFECYCLED_CLOUDWATCH_GROUP=/buildkite/lifecycled
EOF

# Phase 1: Start lifecycled first (CRITICAL for spot instance handling)
echo "Starting lifecycled (required for spot instance handling)..."

# Ensure systemd is ready before operations
sleep 1
systemctl enable --now lifecycled.service

# Verify lifecycled is actually running before proceeding
lifecycled_ready() {
  systemctl is-active --quiet lifecycled.service
}

echo "Waiting for lifecycled to be active..."
timeout=15 # Increased timeout for slower instances
start_time=$(date +%s)
while ! lifecycled_ready; do
  current_time=$(date +%s)
  if [ $((current_time - start_time)) -gt $timeout ]; then
    echo "ERROR: lifecycled failed to start within ${timeout}s - this is critical for spot instance handling"
    echo "Systemd status:"
    systemctl status lifecycled.service || true
    exit 1
  fi
  sleep 0.5
done
echo "lifecycled is running and ready"

# Phase 2: Start parallel preparation tasks
echo "Preparing buildkite-agent startup in parallel..."

# Background task 1: Docker availability check with improved logic
wait_for_docker() {
  local timeout=30
  local start_time
  start_time=$(date +%s)
  local check_count=0

  echo "Checking Docker availability..."
  while ! docker ps >/dev/null 2>&1; do
    local current_time
    current_time=$(date +%s)
    if [ $((current_time - start_time)) -gt "$timeout" ]; then
      echo "ERROR: Docker failed to start within ${timeout}s after ${check_count} attempts"
      exit 1
    fi
    check_count=$((check_count + 1))
    sleep 0.5
  done
  echo "Docker is ready (verified after ${check_count} attempts)"
}

wait_for_docker &
docker_check_pid=$!

# Background task 2: Resource limits configuration
configure_resource_limits() {
  echo "Configuring systemd resource limits for Buildkite agent..."

  local MEMORY_HIGH="${RESOURCE_LIMITS_MEMORY_HIGH:-90%}"
  local MEMORY_MAX="${RESOURCE_LIMITS_MEMORY_MAX:-90%}"
  local MEMORY_SWAP_MAX="${RESOURCE_LIMITS_MEMORY_SWAP_MAX:-90%}"
  local CPU_WEIGHT="${RESOURCE_LIMITS_CPU_WEIGHT:-100}"
  local CPU_QUOTA="${RESOURCE_LIMITS_CPU_QUOTA:-90%}"
  local IO_WEIGHT="${RESOURCE_LIMITS_IO_WEIGHT:-80}"

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

  echo "Resource limits configuration files created successfully"
}

resource_limits_pid=""
if [[ "${ENABLE_RESOURCE_LIMITS:-false}" == "true" ]]; then
  configure_resource_limits &
  resource_limits_pid=$!
fi

# Background task 3: Resource limits configuration already handled above if enabled

# Phase 3: Wait for prerequisites before starting buildkite-agent
echo "Waiting for buildkite-agent prerequisites..."

# Wait for Docker (critical)
wait $docker_check_pid || {
  echo "ERROR: Docker prerequisite failed"
  exit 1
}

# Wait for resource limits configuration (if configured)
if [[ -n "$resource_limits_pid" ]]; then
  wait $resource_limits_pid || {
    echo "ERROR: Resource limits configuration failed"
    exit 1
  }
  echo "Reloading systemd configuration for resource limits..."
  # Add delay to prevent systemd conflicts
  sleep 2
  systemctl daemon-reload
  sleep 1
  echo "Resource limits configured successfully"
fi

# Final background process health check
echo "Final background process health check before buildkite-agent startup..."
show_background_process_status
if ! check_background_process_health; then
  echo "ERROR: Critical background processes have failed before buildkite-agent startup"
  exit 1
fi

# Phase 4: Final buildkite-agent configuration and startup
echo "Writing buildkite-agent systemd environment override..."
# also set in /var/lib/buildkite-agent/cfn-env so that it's shown in the job logs
mkdir -p /etc/systemd/system/buildkite-agent.service.d
cat <<EOF | tee /etc/systemd/system/buildkite-agent.service.d/environment.conf
[Service]
Environment="BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=${BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB}"
EOF

echo "Reloading systemctl services..."
# Add delay to prevent systemd conflicts
sleep 1
systemctl daemon-reload
sleep 2

echo "Starting buildkite-agent (lifecycled is ready for spot handling)..."
systemctl enable --now buildkite-agent

# Verify buildkite-agent started successfully
sleep 2
if ! systemctl is-active --quiet buildkite-agent; then
  echo "ERROR: buildkite-agent failed to start"
  echo "Service status:"
  systemctl status buildkite-agent || true
  exit 1
fi
echo "buildkite-agent is running successfully"

# Signal success to CloudFormation now that buildkite-agent is running
echo "Signaling success to CloudFormation..."
if ! cfn-signal \
  --region "$AWS_REGION" \
  --stack "$BUILDKITE_STACK_NAME" \
  --resource "AgentAutoScaleGroup" \
  --exit-code 0; then
  echo "Warning: CloudFormation signal failed (non-critical - instance may still be marked unhealthy)"
else
  echo "Successfully signaled CloudFormation that instance is ready"
fi

# CloudWatch configuration was started earlier in background and should be completing

# Record bootstrap as complete (this should be the last step in this file)
echo "Completed" >"$STATUS_FILE"
