# Upgrading to Elastic CI Stack v7

Elastic CI Stack v7 uses Buildkite Agent v4. Read the [Agent v3 to v4 upgrade guide](https://buildkite.com/docs/agent/v3-v4-upgrade-guide) first; this page only covers the stack-specific steps.

## Before upgrading

1. Export your current stack parameters:

   ```bash
   aws cloudformation describe-stacks --stack-name MY_STACK_NAME \
     --query 'Stacks[].Parameters[].[ParameterKey,ParameterValue]' --output table
   ```

2. Update parameter files and deployment automation. CloudFormation rejects parameters that aren't in the v7 template:
   - Remove `BuildkiteAgentTimestampLines`. Agent v4 always emits ANSI timestamps.
   - Replace `BuildkiteAgentTracingBackend` with `BuildkiteAgentOpenTelemetryTracing`: `""` becomes `false`, `opentelemetry` becomes `true`, and `datadog` has no direct replacement.
   - Replace `BuildkiteAgentCancelGracePeriod` and `BuildkiteAgentSignalGracePeriod` with `BuildkiteAgentCancelSignalTimeout` and `BuildkiteAgentCancelCleanupTimeout`.
   - Change `BuildkiteAgentRelease=oldstable` to `stable`, `beta`, or `edge`.
3. If you use `AgentEnvFileUrl`, review that file against the Agent upgrade guide. CloudFormation can't check its contents.
4. Preview the update with a [CloudFormation change set](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-updating-stacks-changesets.html).

If you need Agent v3, remain on Elastic CI Stack v6. Stack v7 no longer provides the `oldstable` channel.

## Cancellation timing

Agent v4 separates the time given to a job process from the time reserved for agent cleanup:

- `BuildkiteAgentCancelSignalTimeout` controls how long the process has before SIGKILL.
- `BuildkiteAgentCancelCleanupTimeout` gives a stopping agent extra time to upload logs and artifacts.

Stack v7 defaults to `10s` and `5s`. The v6 defaults allowed 59 seconds for the process and 1 second for cleanup. To keep that timing, set:

```text
BuildkiteAgentCancelSignalTimeout=59s
BuildkiteAgentCancelCleanupTimeout=1s
```

For custom v6 values:

- If `BuildkiteAgentSignalGracePeriod` was `-1`, subtract one second from `BuildkiteAgentCancelGracePeriod` for the new signal timeout and use `1s` for cleanup.
- Otherwise, keep the old signal grace period as the signal timeout. The cleanup timeout is the old cancel grace period minus the signal timeout.

For example, `BuildkiteAgentCancelGracePeriod=120` and `BuildkiteAgentSignalGracePeriod=30` become `30s` and `90s`. The new parameters accept durations such as `30s` and `1m30s`.

## Reviewing `AgentEnvFileUrl`

`AgentEnvFileUrl` still works, but its values configure the Agent directly and can override the generated configuration. Check every custom setting against the Agent upgrade guide. In particular:

- Remove `BUILDKITE_NO_ANSI_TIMESTAMPS` and `BUILDKITE_TIMESTAMP_LINES`.
- Migrate tracing and metrics to OpenTelemetry. This includes replacing `BUILDKITE_TRACING_BACKEND`, renaming `BUILDKITE_TRACING_SERVICE_NAME`, and removing `BUILDKITE_TRACING_PROPAGATE_TRACEPARENT`.
- Replace `BUILDKITE_CANCEL_GRACE_PERIOD` and `BUILDKITE_SIGNAL_GRACE_PERIOD_SECONDS` with `BUILDKITE_CANCEL_SIGNAL_TIMEOUT` and `BUILDKITE_CANCEL_CLEANUP_TIMEOUT`, using the timing conversion above.

Also review any custom Agent experiments before replacing your instances.
