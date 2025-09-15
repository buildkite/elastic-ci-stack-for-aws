#!/bin/bash
set -euo pipefail

echo "Configuring docker cleanup"

DOCKER_GC_SCHEDULE="${DOCKER_GC_SCHEDULE:-hourly}"
DOCKER_GC_PRUNE_UNTIL="${DOCKER_GC_PRUNE_UNTIL:-4h}"
DOCKER_GC_PRUNE_IMAGES="${DOCKER_GC_PRUNE_IMAGES:-false}"
DOCKER_GC_PRUNE_VOLUMES="${DOCKER_GC_PRUNE_VOLUMES:-false}"

if ! [[ "$DOCKER_GC_PRUNE_UNTIL" =~ ^[0-9]+[smhd]$ ]]; then
  echo "Warning: time format not expected: $DOCKER_GC_PRUNE_UNTIL" >&2
  echo "use format like 4h, 30m, 1d" >&2
fi

case "$DOCKER_GC_SCHEDULE" in
hourly | daily | weekly | monthly) ;;
*[0-9]*) ;;
*)
  echo "Warning: time format not expected - $DOCKER_GC_SCHEDULE" >&2
  echo "use hourly, daily, weekly, monthly" >&2
  ;;
esac

echo "Schedule: $DOCKER_GC_SCHEDULE"
echo "Prune older than: $DOCKER_GC_PRUNE_UNTIL"
echo "Cleaning all images: $DOCKER_GC_PRUNE_IMAGES"
echo "Volumes: $DOCKER_GC_PRUNE_VOLUMES"

cat >/usr/local/bin/docker-gc <<'EOF'
#!/bin/bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    exec >> /var/log/elastic-stack.log 2>&1
fi

mark_instance_unhealthy() {
  # cancel any running buildkite builds
  killall -QUIT buildkite-agent || true

  # mark the instance for termination
  echo "Marking instance as unhealthy"

  # shellcheck disable=SC2155
  local token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --fail --silent --show-error --location "http://169.254.169.254/latest/api/token")
  # shellcheck disable=SC2155
  local instance_id=$(curl -H "X-aws-ec2-metadata-token: $token" --fail --silent --show-error --location "http://169.254.169.254/latest/meta-data/instance-id")
  # shellcheck disable=SC2155
  local region=$(curl -H "X-aws-ec2-metadata-token: $token" --fail --silent --show-error --location "http://169.254.169.254/latest/meta-data/placement/region")

  aws autoscaling set-instance-health \
    --instance-id "${instance_id}" \
    --region "${region}" \
    --health-status Unhealthy
}

trap mark_instance_unhealthy ERR

echo "$(date): Docker cleanup starting"

# Check if this is a disk-space triggered cleanup or scheduled cleanup
FORCE_CLEANUP=${1:-""}
if [[ "$FORCE_CLEANUP" != "force" ]]; then
    if /usr/local/bin/bk-check-disk-space.sh >/dev/null 2>&1; then
        echo "$(date): Disk space is sufficient, skipping Docker cleanup"
        exit 0
    fi
    echo "$(date): Disk space is low, proceeding with emergency Docker cleanup"
    
    TIME_FILTER="--filter until=DOCKER_PRUNE_UNTIL_PLACEHOLDER"
    echo "Cleaning up docker resources older than DOCKER_PRUNE_UNTIL_PLACEHOLDER"
    docker image prune --all --force $TIME_FILTER
    docker builder prune --all --force $TIME_FILTER
else
    echo "$(date): Running scheduled Docker cleanup"
    
    TIME_FILTER="--filter until=DOCKER_PRUNE_UNTIL_PLACEHOLDER"

    echo "Cleaning networks and containers"
    docker network prune --force
    docker container prune --force $TIME_FILTER

    if [[ "DOCKER_GC_PRUNE_IMAGES_PLACEHOLDER" == "true" ]]; then
        echo "Cleaning all images"
        docker image prune --all --force $TIME_FILTER
    else
        echo "Cleaning dangling images only"
        docker image prune --force $TIME_FILTER
    fi

    if [[ "DOCKER_GC_PRUNE_VOLUMES_PLACEHOLDER" == "true" ]]; then
        echo "Cleaning volumes"
        docker volume prune --force
    fi
fi

# After cleanup, verify we actually freed up space (but only if this was disk-triggered)
if [[ "$FORCE_CLEANUP" != "force" ]]; then
    if ! /usr/local/bin/bk-check-disk-space.sh; then
        echo "$(date): Disk health checks failed after Docker cleanup" >&2
        exit 1
    fi
fi

echo "$(date): Docker cleanup completed successfully"
EOF

sed -i "s/DOCKER_PRUNE_UNTIL_PLACEHOLDER/$DOCKER_GC_PRUNE_UNTIL/g" /usr/local/bin/docker-gc
sed -i "s/DOCKER_GC_PRUNE_IMAGES_PLACEHOLDER/$DOCKER_GC_PRUNE_IMAGES/g" /usr/local/bin/docker-gc
sed -i "s/DOCKER_GC_PRUNE_VOLUMES_PLACEHOLDER/$DOCKER_GC_PRUNE_VOLUMES/g" /usr/local/bin/docker-gc

chmod +x /usr/local/bin/docker-gc

cat >/etc/systemd/system/docker-gc.timer <<EOF
[Unit]
Description=Docker GC Cleanup Timer
Requires=docker-gc.service

[Timer]
Unit=docker-gc.service
OnCalendar=${DOCKER_GC_SCHEDULE}
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat >/etc/systemd/system/docker-gc.service <<EOF
[Unit]
Description=Docker GC Cleanup
Wants=docker-gc.timer

[Service]
Type=oneshot
ExecStart=/usr/local/bin/docker-gc force
StandardOutput=journal
StandardError=journal
EOF

echo "Enabling timer"
systemctl daemon-reload || {
  echo "Warning: systemctl daemon-reload failed, retrying in 5 seconds"
  sleep 5
  systemctl daemon-reload || {
    echo "Error: systemctl daemon-reload failed twice, skipping timer setup"
    exit 0
  }
}

systemctl enable docker-gc.timer || {
  echo "Warning: failed to enable docker-gc.timer"
}

systemctl start docker-gc.timer || {
  echo "Warning: failed to start docker-gc.timer, will retry later"
}

echo "Docker GC Cleanup configured"
echo "Schedule: $DOCKER_GC_SCHEDULE"
echo "Prune older than: $DOCKER_GC_PRUNE_UNTIL"
if [[ "$DOCKER_GC_PRUNE_IMAGES" == "true" ]]; then
  echo "Will clean all images"
else
  echo "Will clean dangling images only"
fi
if [[ "$DOCKER_GC_PRUNE_VOLUMES" == "true" ]]; then
  echo "Will clean volumes"
else
  echo "Volumes left alone"
fi

echo Restarting docker daemon...
systemctl restart docker
