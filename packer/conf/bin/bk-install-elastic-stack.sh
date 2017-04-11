#!/bin/bash
set -euo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

exec > /var/log/elastic-stack.log 2>&1 # Logs to elastic-stack.log

on_error() {
	local exitCode="$?"
	local errorLine="$1"

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

# cfn-env is sourced by the environment hook in builds
cat << EOF > /var/lib/buildkite-agent/cfn-env
BUILDKITE_STACK_NAME=$BUILDKITE_STACK_NAME
BUILDKITE_SECRETS_BUCKET=$BUILDKITE_SECRETS_BUCKET
BUILDKITE_AGENTS_PER_INSTANCE=$BUILDKITE_AGENTS_PER_INSTANCE
AWS_DEFAULT_REGION=$AWS_REGION
AWS_REGION=$AWS_REGION
EOF

if [[ "${BUILDKITE_ECR_POLICY:-none}" != "none" ]] ; then
	printf "AWS_ECR_LOGIN=1\n" >> /var/lib/buildkite-agent/cfn-env
fi

# Choose the right agent binary
ln -s "/usr/bin/buildkite-agent-${BUILDKITE_AGENT_RELEASE}" /usr/bin/buildkite-agent

# Once 3.0 is stable we can just remove this and let the agent do the right thing
if [[ "${BUILDKITE_AGENT_RELEASE}" == "stable" ]]; then
	BOOTSTRAP_SCRIPT="/etc/buildkite-agent/bootstrap.sh"
else
	BOOTSTRAP_SCRIPT="buildkite-agent bootstrap"
fi;

cat << EOF > /etc/buildkite-agent/buildkite-agent.cfg
name="${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%n"
token="${BUILDKITE_AGENT_TOKEN}"
meta-data=$(printf 'queue=%s,docker=%s,stack=%s,buildkite-aws-stack=%s' "${BUILDKITE_QUEUE}" "${DOCKER_VERSION}" "${BUILDKITE_STACK_NAME}" "${BUILDKITE_STACK_VERSION}")
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
	[/var/log/buildkite-agent-${i}.log]
	file = /var/log/buildkite-agent-${i}.log
	log_group_name = /var/log/buildkite-agent.log
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

# my kingdom for a decent init system
start terminationd || true
service awslogs restart || true

# wait for docker to start
next_wait_time=0
until docker ps || [ $next_wait_time -eq 5 ]; do
   sleep $(( next_wait_time++ ))
done

for i in $(seq 1 "${BUILDKITE_AGENTS_PER_INSTANCE}"); do
	cp /etc/buildkite-agent/init.d.tmpl "/etc/init.d/buildkite-agent-${i}"
	service "buildkite-agent-${i}" start
	chkconfig --add "buildkite-agent-${i}"
done

/opt/aws/bin/cfn-signal \
	--region "$AWS_REGION" \
	--stack "$BUILDKITE_STACK_NAME" \
	--resource "AgentAutoScaleGroup" \
	--exit-code 0
