$ErrorActionPreference = "Stop"

$Token = (Invoke-WebRequest -UseBasicParsing -Method Put `
  -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '30'} `
  http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing `
  -Headers @{'X-aws-ec2-metadata-token' = $Token} `
  http://169.254.169.254/latest/meta-data/instance-id).content

$Region = (Invoke-WebRequest -UseBasicParsing `
  -Headers @{'X-aws-ec2-metadata-token' = $Token} `
  http://169.254.169.254/latest/meta-data/placement/region).content

$AsgName = (aws autoscaling describe-auto-scaling-instances `
  --region "$Region" `
  --instance-ids "$InstanceId" `
  --query 'AutoScalingInstances[0].AutoScalingGroupName' `
  --output text)

if ([string]::IsNullOrEmpty($AsgName) -or $AsgName -eq "None") {
  Write-Output "WARNING: Could not resolve Auto Scaling group name, skipping lifecycle action."
  exit 0
}

Write-Output "Completing warm pool lifecycle action for $InstanceId in $AsgName..."
aws autoscaling complete-lifecycle-action `
  --region "$Region" `
  --auto-scaling-group-name "$AsgName" `
  --lifecycle-hook-name WarmPoolBootstrap `
  --lifecycle-action-result CONTINUE `
  --instance-id "$InstanceId"
if ($lastexitcode -ne 0) {
  Write-Output "WARNING: Failed to complete warm pool lifecycle action, continuing anyway."
}
