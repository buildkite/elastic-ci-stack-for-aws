Start-Transcript -path C:\buildkite-agent\terminate-instance.log -append

$Token = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

Write-Output "$(Get-Date) terminate-instance: requesting instance termination..."
aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--should-decrement-desired-capacity" 2> $null

# The agent service does not restart after it exits, so the instance must be
# replaced if it can't be removed. If the ASG can't decrement (we're already at
# minSize), terminate without decrementing so the ASG launches a replacement.
# If that also fails, mark the instance unhealthy so the ASG replaces it
# despite scale-in protection.
if ($lastexitcode -eq 0) {
  Write-Output "$(Get-Date) terminate-instance: terminating instance..."
} else {
  Write-Output "$(Get-Date) terminate-instance: ASG could not decrement (we're already at minSize), terminating without decrement..."
  aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--no-should-decrement-desired-capacity" 2> $null

  if ($lastexitcode -eq 0) {
    Write-Output "$(Get-Date) terminate-instance: terminating instance (ASG will launch a replacement)..."
  } else {
    Write-Output "$(Get-Date) terminate-instance: termination failed, marking instance as unhealthy"
    aws autoscaling set-instance-health `
      --instance-id "$InstanceId" `
      --region "$Region" `
      --health-status Unhealthy

    # Last resort: the agent won't restart, so shut down and let the ASG
    # replace the stopped instance despite scale-in protection.
    if ($lastexitcode -ne 0) {
      Write-Output "$(Get-Date) terminate-instance: could not mark instance unhealthy, shutting down"
      Stop-Transcript
      shutdown /s /f /t 0
      exit 0
    }
  }
}

Stop-Transcript
