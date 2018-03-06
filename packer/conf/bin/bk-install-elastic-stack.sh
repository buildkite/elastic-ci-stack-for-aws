#!/bin/bash
set -euo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

# Write to system console and to our log file
# See https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee -a /var/log/elastic-stack.log|logger -t user-data -s 2>/dev/console) 2>&1

on_error() {
	local exitCode="$?"
	local errorLine="$1"

	if [[ $exitCode != 0 ]] ; then
		aws autoscaling set-instance-health \
			--instance-id "$(curl http://169.254.169.254/latest/meta-data/instance-id)" \
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

# Cloudwatch logs needs a region specifically configured
cat << EOF > /etc/awslogs/awscli.conf
[plugins]
cwlogs = cwlogs
[default]
region = $AWS_REGION
EOF

PLUGINS_ENABLED=()
[[ $SECRETS_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("secrets")
[[ $ECR_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("ecr")
[[ $DOCKER_LOGIN_PLUGIN_ENABLED == "true" ]] && PLUGINS_ENABLED+=("docker-login")

# cfn-env is sourced by the environment hook in builds
cat << EOF > /var/lib/buildkite-agent/cfn-env
export DOCKER_VERSION=$DOCKER_VERSION
export BUILDKITE_STACK_NAME=$BUILDKITE_STACK_NAME
export BUILDKITE_STACK_VERSION=$BUILDKITE_STACK_VERSION
export BUILDKITE_AGENTS_PER_INSTANCE=$BUILDKITE_AGENTS_PER_INSTANCE
export BUILDKITE_SECRETS_BUCKET=$BUILDKITE_SECRETS_BUCKET
export AWS_DEFAULT_REGION=$AWS_REGION
export AWS_REGION=$AWS_REGION
export PLUGINS_ENABLED="${PLUGINS_ENABLED[*]}"
export BUILDKITE_ECR_POLICY=${BUILDKITE_ECR_POLICY:-none}
EOF

if [[ "${BUILDKITE_AGENT_RELEASE}" == "edge" ]] ; then
	echo "Downloading buildkite-agent edge..."
	curl -Lsf -o /usr/bin/buildkite-agent-edge \
		"https://download.buildkite.com/agent/experimental/latest/buildkite-agent-linux-amd64"
	chmod +x /usr/bin/buildkite-agent-edge
	buildkite-agent-edge --version
fi

# Choose the right agent binary
ln -s "/usr/bin/buildkite-agent-${BUILDKITE_AGENT_RELEASE}" /usr/bin/buildkite-agent

# Once 3.0 is stable we can just remove this and let the agent do the right thing
if [[ "${BUILDKITE_AGENT_RELEASE}" == "stable" ]]; then
	BOOTSTRAP_SCRIPT="/etc/buildkite-agent/bootstrap.sh"
else
	BOOTSTRAP_SCRIPT="buildkite-agent bootstrap"
fi

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

cat << EOF > /etc/buildkite-agent/buildkite-agent.cfg
name="${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%n"
token="${BUILDKITE_AGENT_TOKEN}"
meta-data=$(IFS=, ; echo "${agent_metadata[*]}")
meta-data-ec2=true
bootstrap-script="${BOOTSTRAP_SCRIPT}"
hooks-path=/etc/buildkite-agent/hooks
build-path=/var/lib/buildkite-agent/builds
plugins-path=/var/lib/buildkite-agent/plugins
EOF

chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

for i in $(seq 1 "${BUILDKITE_AGENTS_PER_INSTANCE}"); do
	touch "/var/log/buildkite-agent-${i}.log"

	# Setup logging first so we capture everything
	cat <<- EOF > "/etc/awslogs/config/buildkite-agent-${i}.conf"
	[/buildkite/buildkite-agent-${i}.log]
	file = /var/log/buildkite-agent-${i}.log
	log_group_name = /buildkite/buildkite-agent
	log_stream_name = {instance_id}-${i}
	datetime_format = %Y-%m-%d %H:%M:%S
	EOF
done

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

if [[ -n "${BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT}" ]] ; then
	/usr/local/bin/bk-fetch.sh "${BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT}" /tmp/elastic_bootstrap
	bash < /tmp/elastic_bootstrap
	rm /tmp/elastic_bootstrap
fi

cat << EOF > /etc/lifecycled
AWS_REGION=${AWS_REGION}
LIFECYCLED_SNS_TOPIC=${BUILDKITE_LIFECYCLE_TOPIC}
LIFECYCLED_HANDLER=/usr/local/bin/stop-agent-gracefully
EOF

# my kingdom for a decent init system
start lifecycled || true
service awslogs restart || true

# wait for docker to start
next_wait_time=0
until docker ps || [ $next_wait_time -eq 5 ]; do
	sleep $(( next_wait_time++ ))
done

if ! docker ps ; then
  echo "Failed to contact docker"
  exit 1
fi

for i in $(seq 1 "${BUILDKITE_AGENTS_PER_INSTANCE}"); do
	cp /etc/buildkite-agent/init.d.tmpl "/etc/init.d/buildkite-agent-${i}"
	service "buildkite-agent-${i}" start
	chkconfig --add "buildkite-agent-${i}"
done

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
