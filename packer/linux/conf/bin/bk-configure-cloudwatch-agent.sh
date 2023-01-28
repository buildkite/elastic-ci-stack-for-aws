#!/bin/bash
# shellcheck disable=SC2094
set -euo pipefail

if [[ "${CLOUDWATCH_ENABLE_METRICS:-false}" == "true" ]]; then
    cw_config="/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json"
    cat <<<"$(jq \
        --arg queue "$BUILDKITE_QUEUE" \
        '. + {
            metrics: {
                metrics_collected: {
                    mem: {measurement: ["mem_used_percent"], append_dimensions: {BuildkiteQueue: $queue}},
                    disk: {measurement: ["used_percent"], resources: ["*"], append_dimensions: {BuildkiteQueue: $queue}}
                },
                append_dimensions: {
                    AutoScalingGroupName: "${aws:AutoScalingGroupName}"
                }
            }
        }' $cw_config)" >$cw_config
fi

# Enable and start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
