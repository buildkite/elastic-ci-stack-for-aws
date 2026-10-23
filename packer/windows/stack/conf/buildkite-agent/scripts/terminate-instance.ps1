Start-Transcript -path C:\buildkite-agent\terminate-instance.log -append
$Stopwatch = [Diagnostics.Stopwatch]::StartNew()

# NSSM kills this hook after 60s. Bound every network call so the fallbacks,
# including the shutdown, still run if IMDS or Auto Scaling is unresponsive.
$Env:AWS_RETRY_MODE = "standard"
$Env:AWS_MAX_ATTEMPTS = "2"
$AwsTimeouts = @("--cli-connect-timeout", "2", "--cli-read-timeout", "3")

$Token = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

Write-Output "$(Get-Date) terminate-instance: requesting instance termination..."

# Retry errors that clear on their own, such as throttling when many instances
# scale in together, so the ASG doesn't launch an unnecessary replacement.
# Other errors, such as the ValidationError at minSize, fall through
# immediately. Stop retrying after 15s to leave time for the fallbacks below.
$Backoff = 1

# Retrieve ASG details to check if it's fixed-size (MinSize == MaxSize)
$AsgName = (aws ec2 describe-tags -region "$Region" --filters "Name=resource-id,Values=$InstanceID" "Name=key,Key=aws:autoscaling:groupName" --query "Tags[0].Value" --output text @AwsTimeouts)
$DecrementFlag = "--should-decrement-desired-capacity"

if ($AsgName -and $AsgName -ne "None") {
  $AsgInfo = (aws autoscaling describe-auto-scaling-groups --region "$Region" --auto-scaling-group-namees "$AsgName" --query "AutoScalingGroups[0].[MinSize, MaxSize]" --output text @AwsTimeouts)
  if ($AsgInfo) {
      $Sizes = $AsgInfo -split "`t"
      if ($Sizes.Count -eq 2 -and $Sizes[0] -eq $Sizes[1]) {
        Write-Output "$(Get-Date) terminate-instance: Detected fixed-size ASG (MinSize == MaxSize = $($Sizes[0])). Skipping capacity decrement."
        $DecrementFlag = "--no-should-decrement-desired-capacity"
      }
  }
}

while ($true) {
  # Windows PowerShell wraps each stderr line in an ErrorRecord, which renders a
  # blank line as "System.Management.Automation.RemoteException", so use the
  # exception message for those.
  $Output = (aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--should-decrement-desired-capacity" @AwsTimeouts 2>&1 | ForEach-Object { if ($_ -is [Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ } }) -join "`n"
  if ($lastexitcode -eq 0) { break }
  Write-Output "$(Get-Date) terminate-instance: termination with capacity decrement failed: $($Output.Trim())"
  if ($Output -notmatch '\((Throttling|ResourceContention|ScalingActivityInProgress)\)' -or $Stopwatch.Elapsed.TotalSeconds + $Backoff -gt 15) { break }
  Write-Output "$(Get-Date) terminate-instance: retrying in ${Backoff}s..."
  Start-Sleep -Seconds $Backoff
  $Backoff *= 2
}

# The agent service does not restart after it exits, so the instance must be
# replaced if it can't be removed. If the ASG can't decrement (for example,
# we're already at minSize), terminate without decrementing so the ASG
# launches a replacement. If that also fails, mark the instance unhealthy so
# the ASG replaces it despite scale-in protection.
if ($lastexitcode -eq 0) {
  Write-Output $Output
  Write-Output "$(Get-Date) terminate-instance: terminating instance..."
} else {
  Write-Output "$(Get-Date) terminate-instance: terminating without decrement..."
  aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--no-should-decrement-desired-capacity" @AwsTimeouts 2> $null

  if ($lastexitcode -eq 0) {
    Write-Output "$(Get-Date) terminate-instance: terminating instance (ASG will launch a replacement)..."
  } else {
    Write-Output "$(Get-Date) terminate-instance: termination failed, marking instance as unhealthy"
    aws autoscaling set-instance-health `
      --instance-id "$InstanceId" `
      --region "$Region" `
      --health-status Unhealthy `
      @AwsTimeouts

    # Last resort: the agent won't restart, so shut down and let the ASG
    # replace the stopped instance despite scale-in protection.
    if ($lastexitcode -ne 0) {
      Write-Output "$(Get-Date) terminate-instance: could not mark instance unhealthy, shutting down"
      shutdown /s /f /t 0
      Write-Output "$(Get-Date) terminate-instance: shutdown exited with code $lastexitcode"
      Stop-Transcript
      exit 0
    }
  }
}

Stop-Transcript
