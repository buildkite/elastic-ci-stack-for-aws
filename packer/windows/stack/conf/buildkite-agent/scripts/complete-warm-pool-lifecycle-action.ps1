$ErrorActionPreference = "Stop"

$MaxAttempts = 3

function Get-Metadata {
  param([string]$Path, [int]$Attempts = $MaxAttempts)

  for ($Attempt = 1; $Attempt -le $Attempts; $Attempt++) {
    try {
      $Token = (Invoke-WebRequest -UseBasicParsing -Method Put -TimeoutSec 5 `
        -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '30'} `
        http://169.254.169.254/latest/api/token).content

      return (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 `
        -Headers @{'X-aws-ec2-metadata-token' = $Token} `
        "http://169.254.169.254/latest/meta-data/$Path").content
    } catch {
      # Write-Host, not Write-Output: anything a function writes to the output stream becomes
      # part of its return value, so a logged line here would be returned alongside the value.
      Write-Host "Attempt $Attempt of $Attempts to read metadata '$Path' failed: $($_.Exception.Message)"
      if ($Attempt -lt $Attempts) { Start-Sleep -Seconds ($Attempt * 2) }
    }
  }

  return $null
}

# A native command writing to stderr is a terminating NativeCommandError while
# ErrorActionPreference is Stop, and both AWS calls below are expected to fail sometimes.
function Invoke-AwsCommand {
  param([scriptblock]$Command)

  $ErrorActionPreference = "SilentlyContinue"
  $Output = (& $Command 2>&1) | Out-String
  $ExitCode = $lastexitcode
  $ErrorActionPreference = "Stop"

  return @{ Output = $Output.Trim(); ExitCode = $ExitCode }
}

$InstanceId = Get-Metadata "instance-id"
$Region = Get-Metadata "placement/region"

# Exits non-zero on a real failure so that callers do not start the agent on an instance whose
# lifecycle action is still pending: the hook would time out and ABANDON would terminate it
# mid-job. Being abandoned before taking work is the better outcome.
if ([string]::IsNullOrEmpty($InstanceId) -or [string]::IsNullOrEmpty($Region)) {
  Write-Output "ERROR: Could not read instance metadata, cannot complete lifecycle action."
  exit 1
}

# The launch template enables instance metadata tags and Auto Scaling tags its instances with
# aws:autoscaling:groupName. Preferred over describe-auto-scaling-instances because it keeps an
# Auto Scaling API call off the path to the agent starting, which matters more on Windows where
# the CLI is slower to start, and spares the account's rate limit during a scale-out burst.
#
# Tried once rather than retried: whether IMDS serves reserved aws: tags under tags/instance is
# not documented, and a path it does not serve fails identically on every attempt. Falling
# through immediately costs less than the backoff would.
$AsgName = Get-Metadata "tags/instance/aws:autoscaling:groupName" -Attempts 1

if ([string]::IsNullOrEmpty($AsgName)) {
  # Reached when the tag is unavailable, so the group name is resolved from the API instead. On
  # the InService path a failure here is fatal twice over: the caller exits non-zero, the trap
  # fails the cfn-signal, and stack creation fails for the initial MinSize instances.
  Write-Output "Could not read the Auto Scaling group name from instance metadata tags, falling back to the Auto Scaling API..."

  for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
    $Result = Invoke-AwsCommand {
      aws autoscaling describe-auto-scaling-instances `
        --region "$Region" `
        --instance-ids "$InstanceId" `
        --query 'AutoScalingInstances[0].AutoScalingGroupName' `
        --output text
    }

    if ($Result.ExitCode -eq 0) {
      $AsgName = $Result.Output
      break
    }

    Write-Output "Attempt $Attempt of $MaxAttempts to resolve Auto Scaling group name failed: $($Result.Output)"
    if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds ($Attempt * 2) }
  }

  # --output text renders a missing value as the literal string None, not as empty output.
  if ([string]::IsNullOrEmpty($AsgName) -or $AsgName -eq "None") {
    Write-Output "ERROR: Could not resolve Auto Scaling group name, cannot complete lifecycle action."
    exit 1
  }
}

Write-Output "Completing warm pool lifecycle action for $InstanceId in $AsgName..."
for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
  $Result = Invoke-AwsCommand {
    aws autoscaling complete-lifecycle-action `
      --region "$Region" `
      --auto-scaling-group-name "$AsgName" `
      --lifecycle-hook-name WarmPoolBootstrap `
      --lifecycle-action-result CONTINUE `
      --instance-id "$InstanceId"
  }

  if ($Result.ExitCode -eq 0) {
    Write-Output "Completed warm pool lifecycle action."
    exit 0
  }

  # Expected on the initial MinSize instances, which launch before the hook exists. This
  # script only runs on a warm pool stack, so there is no pending action to find on those.
  # Not a failure, so do not retry it.
  if ($Result.Output -match "No active Lifecycle Action found") {
    Write-Output "No pending lifecycle action, nothing to complete."
    exit 0
  }

  Write-Output "Attempt $Attempt of $MaxAttempts to complete lifecycle action failed: $($Result.Output)"
  if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds ($Attempt * 2) }
}

Write-Output "ERROR: Failed to complete warm pool lifecycle action after $MaxAttempts attempts."
exit 1
