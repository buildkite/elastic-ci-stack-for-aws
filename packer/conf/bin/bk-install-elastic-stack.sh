#!/bin/bash
set -euo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

exec > /var/log/elastic-stack.log 2>&1 # Logs to elastic-stack.log

on_error() {
	local exitCode="$?"
	local errorLine="$1"

	aws autoscaling set-instance-health \
		--instance-id "$INSTANCE_ID" \
		--health-status Unhealthy

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

# .env is read by docker-compose
cat << EOF > /var/lib/buildkite-agent/.env
AWS_DEFAULT_REGION=$AWS_REGION
AWS_REGION=$AWS_REGION
BUILDKITE_STACK_NAME=$BUILDKITE_STACK_NAME
BUILDKITE_SECRETS_BUCKET=$BUILDKITE_SECRETS_BUCKET
BUILDKITE_AGENT_RELEASE=$BUILDKITE_AGENT_RELEASE
BUILDKITE_AGENTS_PER_INSTANCE=$BUILDKITE_AGENTS_PER_INSTANCE
BUILDKITE_AGENT_ACCESS_TOKEN=${BUILDKITE_AGENT_TOKEN}
BUILDKITE_AGENT_NAME=${BUILDKITE_STACK_NAME}-${INSTANCE_ID}-%n
BUILDKITE_AGENT_META_DATA=$(printf 'queue=%s,docker=%s,stack=%s,buildkite-aws-stack=%s' "${BUILDKITE_QUEUE}" "${DOCKER_VERSION}" "${BUILDKITE_STACK_NAME}" "${BUILDKITE_STACK_VERSION}")
BUILDKITE_AGENT_META_DATA_EC2=true
EOF

if [[ "${BUILDKITE_ECR_POLICY:-none}" != "none" ]] ; then
	printf "AWS_ECR_LOGIN=1\n" >> /var/lib/buildkite-agent/.env
fi

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

docker-compose -f /var/lib/buildkite-agent/docker-compose.yml up -d
docker-compose -f /var/lib/buildkite-agent/docker-compose.yml scale "agent=$BUILDKITE_AGENTS_PER_INSTANCE"

/opt/aws/bin/cfn-signal \
	--region "$AWS_REGION" \
	--stack "$BUILDKITE_STACK_NAME" \
	--resource "AgentAutoScaleGroup" \
	--exit-code 0
