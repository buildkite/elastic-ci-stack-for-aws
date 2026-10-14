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
    # The agent is not started when the hook could not be completed: the instance is abandoned
    # at the hook timeout instead of being terminated mid-job.
    Write-Output "Target lifecycle state is InService, completing lifecycle action..."
    powershell -file C:\buildkite-agent\bin\complete-warm-pool-lifecycle-action.ps1

    if ($lastexitcode -ne 0) {
      Write-Output "Could not complete lifecycle action, not starting the agent."
      Stop-Transcript
      exit 1
    }

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
