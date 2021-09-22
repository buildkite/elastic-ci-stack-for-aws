#!/bin/bash
set -euxo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log|logger -t user-data -s 2>/dev/console) 2>&1

on_error() {
	local exitCode="$?"
	local errorLine="$1"

	# If the curl fails, we're already in the error trap...
	# shellcheck disable=SC2155
	local token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --fail --silent --show-error --location "http://169.254.169.254/latest/api/token")

	if [[ $exitCode != 0 ]] ; then
		aws autoscaling set-instance-health \
			--instance-id "$(curl -H "X-aws-ec2-metadata-token: $token" --fail --silent --show-error --location "http://169.254.169.254/latest/meta-data/instance-id")" \
			--health-status Unhealthy || true
	fi

	/opt/aws/bin/cfn-signal \
		--region "$AWS_REGION" \
		--stack "$BUILDKITE_STACK_NAME" \
		--reason "Error on line $errorLine: $(tail -n 1 /var/log/elastic-stack.log)" \
		--resource "AgentAutoScaleGroup" \
		--exit-code "$exitCode"
}

trap 'on_error $LINENO' ERR

INSTANCE_ID=$(/opt/aws/bin/ec2-metadata --instance-id | cut -d " " -f 2)
DOCKER_VERSION=$(docker --version | cut -f3 -d' ' | sed 's/,//')

PLUGINS_ENABLED=()
[[ $SECRETS_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("secrets")
[[ $ECR_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("ecr")
[[ $DOCKER_LOGIN_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("docker-login")

# cfn-env is sourced by the environment hook in builds

# We will create it in two steps so that we don't need to go crazy with quoting and escaping. The
# first sets up a helper function, the second populates the default values for some environment
# variables.

# Step 1: Helper function.  Note that we clobber the target file and DO NOT apply variable
# substitution, this is controlled by the double-quoted "EOF".
cat <<- "EOF" > /var/lib/buildkite-agent/cfn-env
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
cat << EOF >> /var/lib/buildkite-agent/cfn-env

set_always         "BUILDKITE_AGENTS_PER_INSTANCE" "$BUILDKITE_AGENTS_PER_INSTANCE"
set_always         "BUILDKITE_ECR_POLICY" "${BUILDKITE_ECR_POLICY:-none}"
set_always         "BUILDKITE_SECRETS_BUCKET" "$BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_STACK_NAME" "$BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_VERSION" "$DOCKER_VERSION"
set_always         "PLUGINS_ENABLED" "${PLUGINS_ENABLED[*]-}"
set_unless_present "AWS_DEFAULT_REGION" "$AWS_REGION"
set_unless_present "AWS_REGION" "$AWS_REGION"
EOF

if [[ "${BUILDKITE_AGENT_RELEASE}" == "edge" ]] ; then
	if [[ "$(uname -m)" == "aarch64" ]] ; then
	  AGENT_ARCH="arm64"
	else
	  AGENT_ARCH="amd64"
	fi
	echo "Downloading buildkite-agent edge..."
	curl -Lsf -o /usr/bin/buildkite-agent-edge \
		"https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-${AGENT_ARCH}"
	chmod +x /usr/bin/buildkite-agent-edge
	buildkite-agent-edge --version
fi

if [[ "${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" != "" ]] ; then
  echo "buildkite-agent ALL=NOPASSWD: ${BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS}" > /etc/sudoers.d/buildkite-agent-additional
  chmod 440 /etc/sudoers.d/buildkite-agent-additional
fi

# Choose the right agent binary
ln -s "/usr/bin/buildkite-agent-${BUILDKITE_AGENT_RELEASE}" /usr/bin/buildkite-agent

agent_metadata=(
	"queue=${BUILDKITE_QUEUE}"
	"docker=${DOCKER_VERSION}"
	"stack=${BUILDKITE_STACK_NAME}"
	"buildkite-aws-stack=${BUILDKITE_STACK_VERSION}"
)

# Split on commas
if [[ -n "${BUILDKITE_AGENT_TAGS:-}" ]] ; then
	IFS=',' read -r -a extra_agent_metadata <<< "${BUILDKITE_AGENT_TAGS:-}"
	agent_metadata=("${agent_metadata[@]}" "${extra_agent_metadata[@]}")
fi

# Enable git-mirrors
BUILDKITE_AGENT_GIT_MIRRORS_PATH=""
if [[ "${BUILDKITE_AGENT_ENABLE_GIT_MIRRORS_EXPERIMENT}" == "true" ]] ; then
  if [[ -z "$BUILDKITE_AGENT_EXPERIMENTS" ]] ; then
    BUILDKITE_AGENT_EXPERIMENTS="git-mirrors"
  else
    BUILDKITE_AGENT_EXPERIMENTS+=",git-mirrors"
  fi

  BUILDKITE_AGENT_GIT_MIRRORS_PATH="/var/lib/buildkite-agent/git-mirrors"
  mkdir -p "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"

  if [ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]
  then
    EPHEMERAL_GIT_MIRRORS_PATH="/mnt/ephemeral/git-mirrors"
    mkdir -p "${EPHEMERAL_GIT_MIRRORS_PATH}"

    mount -o bind "${EPHEMERAL_GIT_MIRRORS_PATH}" "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"
    echo "${EPHEMERAL_GIT_MIRRORS_PATH} ${BUILDKITE_AGENT_GIT_MIRRORS_PATH} none defaults,bind 0 0" >>/etc/fstab
  fi

  chown buildkite-agent: "${BUILDKITE_AGENT_GIT_MIRRORS_PATH}"
fi

BUILDKITE_AGENT_BUILD_PATH="/var/lib/buildkite-agent/builds"
mkdir -p "${BUILDKITE_AGENT_BUILD_PATH}"
if [ "${BUILDKITE_ENABLE_INSTANCE_STORAGE:-false}" == "true" ]
then
  EPHEMERAL_BUILD_PATH="/mnt/ephemeral/builds"
  mkdir -p "${EPHEMERAL_BUILD_PATH}"
  mount -o bind "${EPHEMERAL_BUILD_PATH}" "${BUILDKITE_AGENT_BUILD_PATH}"
  echo "${EPHEMERAL_BUILD_PATH} ${BUILDKITE_AGENT_BUILD_PATH} none defaults,bind 0 0" >>/etc/fstab
fi
chown buildkite-agent: "${BUILDKITE_AGENT_BUILD_PATH}"

BUILDKITE_AGENT_TOKEN="$(aws ssm get-parameter --name "${BUILDKITE_AGENT_TOKEN_PATH}" --with-decryption --query Parameter.Value --output text)"

cat << EOF > /etc/buildkite-agent/buildkite-agent.cfg
name="${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%spawn"
token="${BUILDKITE_AGENT_TOKEN}"
tags=$(IFS=, ; echo "${agent_metadata[*]}")
tags-from-ec2-meta-data=true
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
EOF

chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

if [[ -n "${BUILDKITE_AUTHORIZED_USERS_URL}" ]] ; then
	cat <<- EOF > /etc/cron.hourly/authorized_keys
	/usr/local/bin/bk-fetch.sh "${BUILDKITE_AUTHORIZED_USERS_URL}" /tmp/authorized_keys
	mv /tmp/authorized_keys /home/ec2-user/.ssh/authorized_keys
	chmod 600 /home/ec2-user/.ssh/authorized_keys
	chown ec2-user: /home/ec2-user/.ssh/authorized_keys
	EOF

	chmod +x /etc/cron.hourly/authorized_keys
	/etc/cron.hourly/authorized_keys
fi

# Finish git lfs install
su buildkite-agent -l -c 'git lfs install'

if [[ -n "${BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT}" ]] ; then
	/usr/local/bin/bk-fetch.sh "${BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT}" /tmp/elastic_bootstrap
	bash < /tmp/elastic_bootstrap
	rm /tmp/elastic_bootstrap
fi

cat << EOF > /etc/lifecycled
AWS_REGION=${AWS_REGION}
LIFECYCLED_HANDLER=/usr/local/bin/stop-agent-gracefully
LIFECYCLED_CLOUDWATCH_GROUP=/buildkite/lifecycled
EOF

systemctl enable lifecycled.service
systemctl start lifecycled

# wait for docker to start
next_wait_time=0
until docker ps || [ $next_wait_time -eq 5 ]; do
	sleep $(( next_wait_time++ ))
done

if ! docker ps ; then
  echo "Failed to contact docker"
  exit 1
fi

systemctl enable "buildkite-agent"
systemctl start "buildkite-agent"

# let the stack know that this host has been initialized successfully
/opt/aws/bin/cfn-signal \
	--region "$AWS_REGION" \
	--stack "$BUILDKITE_STACK_NAME" \
	--resource "AgentAutoScaleGroup" \
	--exit-code 0 || (
		# This will fail if the stack has already completed, for instance if there is a min size
		# of 1 and this is the 2nd instance. This is ok, so we just ignore the erro
		echo "Signal failed"
	)
