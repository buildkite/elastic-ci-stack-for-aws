Start-Transcript -path C:\buildkite-agent\terminate-instance.log -append

$Token = (Invoke-WebRequest -UseBasicParsing -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

Write-Output "$(Get-Date) terminate-instance: requesting instance termination..."
aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--should-decrement-desired-capacity" 2> $null

# If autoscaling request was successful, we will terminate the instance, otherwise, if
# BuildkiteTerminateInstanceAfterJob is set to true, we will mark the instance as unhealthy
# so that the ASG will terminate it despite scale-in protection. Otherwise, we should not
# terminate the instance, so we need to retart the agent.
if ($lastexitcode -eq 0) {
  Write-Output "$(Get-Date) terminate-instance: terminating instance..."
} else {
  Write-Output "$(Get-Date) terminate-instance: ASG could not decrement (we're already at minSize)"
  if ($Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB -eq "true") {
    Write-Output "$(Get-Date) terminate-instance: marking instance as unhealthy"
    aws autoscaling set-instance-health `
      --instance-id "$InstanceId" `
      --region "$Region" `
      --health-status Unhealthy
  } else {
    Write-Output "$(Get-Date) terminate-instance: restarting agent..."
    nssm start buildkite-agent
  }
}

Stop-Transcript
