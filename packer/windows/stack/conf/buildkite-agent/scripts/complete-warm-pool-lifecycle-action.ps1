$ErrorActionPreference = "Stop"

$MaxAttempts = 3

function Get-Metadata {
  param([string]$Path)

  for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
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
      Write-Host "Attempt $Attempt of $MaxAttempts to read metadata '$Path' failed: $($_.Exception.Message)"
      if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds ($Attempt * 2) }
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

if ([string]::IsNullOrEmpty($InstanceId) -or [string]::IsNullOrEmpty($Region)) {
  Write-Output "WARNING: Could not read instance metadata, skipping lifecycle action."
  exit 0
}

$AsgName = $null
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

if ([string]::IsNullOrEmpty($AsgName) -or $AsgName -eq "None") {
  Write-Output "WARNING: Could not resolve Auto Scaling group name, skipping lifecycle action."
  exit 0
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

  # Expected on stacks without a warm pool, and on the initial MinSize instances that
  # launch before the hook exists. Not a failure, so do not retry it.
  if ($Result.Output -match "No active Lifecycle Action found") {
    Write-Output "No pending lifecycle action, nothing to complete."
    exit 0
  }

  Write-Output "Attempt $Attempt of $MaxAttempts to complete lifecycle action failed: $($Result.Output)"
  if ($Attempt -lt $MaxAttempts) { Start-Sleep -Seconds ($Attempt * 2) }
}

Write-Output "WARNING: Failed to complete warm pool lifecycle action after $MaxAttempts attempts."
