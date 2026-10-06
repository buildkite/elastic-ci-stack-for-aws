# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$LifecycleTransition = $args[0]

if ($LifecycleTransition -eq "autoscaling:EC2_INSTANCE_LAUNCHING") {
  Write-Output "Instance transitioning to InService, starting buildkite-agent..."
  Start-Service buildkite-agent
  exit $LASTEXITCODE
}

Write-Output "Stopping buildkite-agent gracefully"

Stop-Service -Verbose buildkite-agent

Write-Output "All buildkite-agent processes have stopped"
