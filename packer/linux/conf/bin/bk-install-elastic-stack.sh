#!/usr/bin/env bash

set -Eeuo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

on_error() {
  local exit_code="$?"
  local error_line="$1"

  echo "${BASH_SOURCE[0]} errored with exit code ${exit_code} on line ${error_line}."

  if [[ $exit_code != 0 ]]; then
    if ! aws autoscaling set-instance-health \
      --instance-id "$INSTANCE_ID" \
      --health-status Unhealthy
    then
      echo Failed to set instance health to unhealthy >&2
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
  echo "${BASH_SOURCE[0]} completed successfully." >&2
}

trap on_exit EXIT

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log | logger -t user-data -s 2>/dev/console) 2>&1

# This needs to happen first so that the error reporting works
token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --fail --silent --show-error --location http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $token" --fail --silent --show-error --location http://169.254.169.254/latest/meta-data/instance-id)
echo "Detected INSTANCE_ID=$INSTANCE_ID" >&2

# This script is run on every boot so that we can gracefully recover from hard failures (eg. kernel panics) during
# any previous attempts. If a previous run is detected as started but not complete then we will fail this run and mark
# the instance as unhealthy.
STATUS_FILE=/var/log/elastic-stack-bootstrap-status

check_status() {
  echo "Checking status file $STATUS_FILE..." >&2

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
  x86_64)    ARCH=amd64;;
  aarch64)   ARCH=arm64;;
  *)         ARCH=unknown;;
esac
echo "Detected ARCH=$ARCH" >&2

DOCKER_VERSION=$(docker --version | cut -f3 -d' ' | sed 's/,//')
echo "Detected DOCKER_VERSION=$DOCKER_VERSION" >&2

PLUGINS_ENABLED=()
[[ $SECRETS_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("secrets")
[[ $ECR_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("ecr")
[[ $DOCKER_LOGIN_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("docker-login")
echo "The following plugins will be enabled: ${PLUGINS_ENABLED[*]-}" >&2

# cfn-env is sourced by the environment hook in builds
# DO NOT PUT SECRETES IN HERE, they will appear in both the cloudwatch and
# build logs, and the agent's log redactor will not be able to redact them.

# We will create it in two steps so that we don't need to go crazy with quoting and escaping. The
# first sets up a helper function, the second populates the default values for some environment
# variables.

# Step 1: Helper function.  Note that we clobber the target file and DO NOT apply variable
# substitution, this is controlled by the double-quoted "EOF".
echo Writing Phase 1/2 for /var/lib/buildkite-agent/cfn-env helper function... >&2
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
echo Writing Phase 2/2 for /var/lib/buildkite-agent/cfn-env helper function... >&2
cat <<EOF >>/var/lib/buildkite-agent/cfn-env

set_always         "BUILDKITE_AGENTS_PER_INSTANCE" "$BUILDKITE_AGENTS_PER_INSTANCE"
set_always         "BUILDKITE_ECR_POLICY" "${BUILDKITE_ECR_POLICY:-none}"
set_always         "BUILDKITE_SECRETS_BUCKET" "$BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_SECRETS_BUCKET_REGION" "$BUILDKITE_SECRETS_BUCKET_REGION"
set_always         "BUILDKITE_STACK_NAME" "$BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_VERSION" "$DOCKER_VERSION"
set_always         "PLUGINS_ENABLED" "${PLUGINS_ENABLED[*]-}"
set_unless_present "AWS_DEFAULT_REGION" "$AWS_REGION"
set_unless_present "AWS_REGION" "$AWS_REGION"
EOF

# We warned about not putting secrets in this file
echo Wrote to /var/lib/buildkite-agent/cfn-env: >&2
cat /var/lib/buildkite-agent/cfn-env >&2
echo

if [[ "${BUILDKITE_AGENT_RELEASE}" == "edge" ]]; then
  echo Downloading buildkite-agent edge... >&2
  curl -Lsf -o /usr/bin/buildkite-agent-edge \
    "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-${ARCH}"
  chmod +x /usr/bin/buildkite-agent-edge
  buildkite-agent-edge --version
else
  echo Not using buildkite-agent edge. >&2
fi

if [[ "${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" != "" ]]; then
  echo "buildkite-agent ALL=NOPASSWD: ${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" \
    >/etc/sudoers.d/buildkite-agent-additional
  chmod 440 /etc/sudoers.d/buildkite-agent-additional

  echo Wrote to /etc/sudoers.d/buildkite-agent-additional... >&2
  cat /etc/sudoers.d/buildkite-agent-additional >&2
else
  echo No additional sudo permissions. >&2
fi

# Choose the right agent binary
ln -sf "/usr/bin/buildkite-agent-$BUILDKITE_AGENT_RELEASE" /usr/bin/buildkite-agent

agent_metadata=(
  "queue=${BUILDKITE_QUEUE}"
  "docker=${DOCKER_VERSION}"
  "stack=${BUILDKITE_STACK_NAME}"
  "buildkite-aws-stack=${BUILDKITE_STACK_VERSION}"
)

echo "Initial agent metadata: ${agent_metadata[*]-}" >&2
if [[ -n "${BUILDKITE_AGENT_TAGS:-}" ]]; then
  IFS=',' read -r -a extra_agent_metadata <<<"${BUILDKITE_AGENT_TAGS:-}"
  agent_metadata=("${agent_metadata[@]}" "${extra_agent_metadata[@]}")
fi
echo "Agent metadata after splitting commas: ${agent_metadata[*]-}" >&2

# Enable git-mirrors
BUILDKITE_AGENT_GIT_MIRRORS_PATH=""
if [[ "${BUILDKITE_AGENT_ENABLE_GIT_MIRRORS:-false}" == "true" ]]; then
  BUILDKITE_AGENT_GIT_MIRRORS_PATH=/var/lib/buildkite-agent/git-mirrors
  echo "git-mirrors enabled at $BUILDKITE_AGENT_GIT_MIRRORS_PATH" >&2
  mkdir -p "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"

  if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]]; then
    echo Mounting git-mirrors to instance storage... >&2

    EPHEMERAL_GIT_MIRRORS_PATH="/mnt/ephemeral/git-mirrors"
    echo "Creating ephemeral git-mirrors direcotry at $EPHEMERAL_GIT_MIRRORS_PATH" >&2
    mkdir -p "${EPHEMERAL_GIT_MIRRORS_PATH}"

    echo Bind mounting ephemeral git-mirror directory to git-mirrors path... >&2
    mount -o bind "${EPHEMERAL_GIT_MIRRORS_PATH}" "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"

    echo Writing bind mount to fstab... >&2
    echo "${EPHEMERAL_GIT_MIRRORS_PATH} ${BUILDKITE_AGENT_GIT_MIRRORS_PATH} none defaults,bind 0 0" >>/etc/fstab

    echo fstab is now: >&2
    cat /etc/fstab >&2
    echo
  else
    echo Not mounting git-mirrors to instance storage as instance storage is disabled. >&2
  fi

  echo Setting ownership of git-mirrors directory to buildkite-agent... >&2
  chown buildkite-agent: "$BUILDKITE_AGENT_GIT_MIRRORS_PATH"
else
  echo git-mirrors disabled. >&2
fi
echo "BUILDKITE_AGENT_GIT_MIRRORS_PATH is $BUILDKITE_AGENT_GIT_MIRRORS_PATH" >&2

BUILDKITE_AGENT_BUILD_PATH="/var/lib/buildkite-agent/builds"
mkdir -p "${BUILDKITE_AGENT_BUILD_PATH}"
if [[ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]]; then
  echo Bind mounting build path to instance storage... >&2

  EPHEMERAL_BUILD_PATH="/mnt/ephemeral/builds"
  mkdir -p "${EPHEMERAL_BUILD_PATH}"

  mount -o bind "${EPHEMERAL_BUILD_PATH}" "${BUILDKITE_AGENT_BUILD_PATH}"
  echo "${EPHEMERAL_BUILD_PATH} ${BUILDKITE_AGENT_BUILD_PATH} none defaults,bind 0 0" >>/etc/fstab

  echo fstab is now: >&2
  cat /etc/fstab >&2
else
  echo Not mounting build path to instance storage as instance storage is disabled. >&2
fi

echo Setting ownership of build path to buildkite-agent. >&2
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
echo Set \$BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS to \$BUILDKITE_AGENT_TIMESTAMP_LINES >&2
echo "BUILDKITE_AGENT_TIMESTAMP_LINES is $BUILDKITE_AGENT_TIMESTAMPS_LINES" >&2
echo "BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS is $BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS" >&2

echo "Setting \$BUILDKITE_AGENT_TOKEN from SSM Parameter $BUILDKITE_AGENT_TOKEN_PATH" >&2
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
tags=$(IFS=, ; echo "${agent_metadata[*]}")
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
tracing-backend=${BUILDKITE_AGENT_TRACING_BACKEND}
cancel-grace-period=60
EOF

if [[ "${BUILDKITE_ENV_FILE_URL}" != "" ]]; then
  echo "Fetching env file from ${BUILDKITE_ENV_FILE_URL}..." >&2
  /usr/local/bin/bk-fetch.sh "${BUILDKITE_ENV_FILE_URL}" /var/lib/buildkite-agent/env
else
  echo No env file to fetch. >&2
fi

echo Setting ownership of /etc/buildkite-agent/buildkite-agent.cfg to buildkite-agent... >&2
chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

if [[ -n "$BUILDKITE_AUTHORIZED_USERS_URL" ]]; then
  echo Writing authorized user fetching script... >&2
  cat <<-EOF | tee /usr/local/bin/refresh_authorized_keys
		/usr/local/bin/bk-fetch.sh "$BUILDKITE_AUTHORIZED_USERS_URL" /tmp/authorized_keys
		mv /tmp/authorized_keys /home/ec2-user/.ssh/authorized_keys
		chmod 600 /home/ec2-user/.ssh/authorized_keys
		chown ec2-user: /home/ec2-user/.ssh/authorized_keys
	EOF

  echo Setting ownership of /usr/local/bin/refresh_authorized_keys to root... >&2
  chmod +x /usr/local/bin/refresh_authorized_keys

  echo Running authorized user fetching script... >&2
  /usr/local/bin/refresh_authorized_keys

  echo Enabling authorized user fetching timer... >&2
  systemctl enable refresh_authorized_keys.timer
else
  echo No authorized users to fetch >&2
fi

echo Installing git-lfs for buildkite-agent user... >&2
su buildkite-agent -l -c 'git lfs install'

if [[ -n "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" ]]; then
  echo "Running bootstrap script from $BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT..." >&2
  /usr/local/bin/bk-fetch.sh "$BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" /tmp/elastic_bootstrap
  bash </tmp/elastic_bootstrap
  rm /tmp/elastic_bootstrap
else
  echo No bootstrap script to run. >&2
fi

echo Writing lifecycled configuration... >&2
cat <<EOF | tee /etc/lifecycled
AWS_REGION=$AWS_REGION
LIFECYCLED_HANDLER=/usr/local/bin/stop-agent-gracefully
LIFECYCLED_CLOUDWATCH_GROUP=/buildkite/lifecycled
EOF

echo Starting lifecycled... >&2
systemctl enable --now lifecycled.service

echo Waiting for docker to start... >&2
check_docker() {
  if ! docker ps >/dev/null; then
    echo "Failed to contact docker."
    return 1
  fi
}

next_wait_time=0
until check_docker || [[ $next_wait_time -eq 5 ]]; do
  sleep $((next_wait_time++))
done

echo "Waited $next_wait_time times for docker to start." >&2
echo We will exit if it still has not started. >&2
check_docker

echo Starting buildkite-agent... >&2
systemctl enable --now buildkite-agent

echo Signaling success to CloudFormation... >&2
# This will fail if the stack has already completed, for instance if there is a min size
# of 1 and this is the 2nd instance. This is ok, so we just ignore the error
cfn-signal \
  --region "$AWS_REGION" \
  --stack "$BUILDKITE_STACK_NAME" \
  --resource "AgentAutoScaleGroup" \
  --exit-code 0 || echo Signal failed

# Record bootstrap as complete (this should be the last step in this file)
echo "Completed" >"$STATUS_FILE"
