# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Downloading amazon cloudwatch agent..."
Invoke-WebRequest -OutFile C:\packer-temp\amazon-cloudwatch-agent.msi -Uri "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"

Write-Output "Installing amazon cloudwatch agent..."
$process = Start-Process msiexec -ArgumentList "/i", "C:\packer-temp\amazon-cloudwatch-agent.msi", "/quiet", "/norestart" -Wait -PassThru
If ($process.ExitCode -ne 0) { Exit $process.ExitCode }

Write-Output "Setting amazon cloudwatch agent start type to manual (will be configured in stack layer)..."
sc.exe config AmazonCloudWatchAgent start= demand
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "CloudWatch agent installed. Configuration will be done in stack layer."
