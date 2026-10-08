$ErrorActionPreference = "Stop"

Start-Transcript -path C:\buildkite-agent\warm-pool-watcher.log -append

function Get-TargetLifecycleState {
  try {
    $Token = (Invoke-WebRequest -UseBasicParsing -Method Put `
      -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '30'} `
      http://169.254.169.254/latest/api/token).content

    return (Invoke-WebRequest -UseBasicParsing `
      -Headers @{'X-aws-ec2-metadata-token' = $Token} `
      http://169.254.169.254/latest/meta-data/autoscaling/target-lifecycle-state).content
  } catch {
    return $null
  }
}

while ($true) {
  $State = Get-TargetLifecycleState

  if ($null -eq $State) {
    Write-Output "Could not read target-lifecycle-state, retrying..."
    Start-Sleep -Seconds 5
    continue
  }

  if ($State -eq "InService") {
    # The hook is completed before the agent starts, so a failure here cannot leave an agent
    # taking jobs while the hook times out and ABANDON terminates the instance mid-job.
    Write-Output "Target lifecycle state is InService, completing lifecycle action..."
    powershell -file C:\buildkite-agent\bin\complete-warm-pool-lifecycle-action.ps1

    Write-Output "Starting buildkite-agent..."
    Start-Service buildkite-agent
    break
  } elseif ($State -like "Warmed:*") {
    Start-Sleep -Seconds 5
  } else {
    Write-Output "Unexpected target lifecycle state '$State', exiting without starting the agent."
    break
  }
}

Stop-Transcript
