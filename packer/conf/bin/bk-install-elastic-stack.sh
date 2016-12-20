#!/bin/bash
set -euo pipefail

## Installs the Buildkite Agent, run from the CloudFormation template

INSTANCE_ID=$(/opt/aws/bin/ec2-metadata --instance-id | cut -d " " -f 2)
DOCKER_VERSION=$(docker --version | cut -f3 -d' ' | sed 's/,//')

env

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
AWS_DEFAULT_REGION=$AWS_REGION
AWS_REGION=$AWS_REGION
EOF

if [[ "${BUILDKITE_ECR_POLICY:-none}" != "none" ]] ; then
	printf "AWS_ECR_LOGIN=1\n" >> /var/lib/buildkite-agent/cfn-env
fi

# Start docker up
service docker start || ( cat /var/log/docker && false )
docker ps > /dev/null

# Choose the right agent binary
ln -s /usr/bin/buildkite-agent-${BUILDKITE_AGENT_RELEASE} /usr/bin/buildkite-agent

# Once 3.0 is stable we can just remove this and let the agent do the right thing
if [[ "${BUILDKITE_AGENT_RELEASE}" == "stable" ]]; then
	BOOTSTRAP_SCRIPT="/etc/buildkite-agent/bootstrap.sh"
else
	BOOTSTRAP_SCRIPT="buildkite-agent bootstrap"
fi;

cat << EOF > /etc/buildkite-agent/buildkite-agent.cfg
name="${AWS_STACK}-${INSTANCE_ID}-%n"
token="${BUILDKITE_AGENT_TOKEN}"
meta-data=\$(printf 'queue=%s,docker=%s,stack=%s,buildkite-aws-stack' "${BUILDKITE_QUEUE}" "${DOCKER_VERSION}" "${AWS_STACK}")
meta-data-ec2=true
bootstrap-script="${BOOTSTRAP_SCRIPT}"
hooks-path=/etc/buildkite-agent/hooks
build-path=/var/lib/buildkite-agent/builds
plugins-path=/var/lib/buildkite-agent/plugins
EOF

chown buildkite-agent: /etc/buildkite-agent/buildkite-agent.cfg

for i in $(seq 1 ${BUILDKITE_AGENTS_PER_INSTANCE}); do
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

service awslogs restart

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
	/usr/local/bin/bk-fetch.sh "${BUILDKITE_AUTHORIZED_USERS_URL}" /tmp/elastic_bootstrap
	bash < /tmp/elastic_bootstrap
	rm /tmp/elastic_bootstrap
fi

# Start services
for i in $(seq 1 ${BUILDKITE_AGENTS_PER_INSTANCE}); do
	cp /etc/buildkite-agent/init.d.tmpl /etc/init.d/buildkite-agent-${i}
	service buildkite-agent-${i} start
	chkconfig --add buildkite-agent-${i}
done

# Make sure terminationd is started if it isn't
start terminationd || true
