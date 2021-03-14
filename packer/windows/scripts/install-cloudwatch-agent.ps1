# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Downloading amazon cloudwatch agent..."
Invoke-WebRequest -OutFile C:\packer-temp\amazon-cloudwatch-agent.msi -Uri "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"

Write-Output "Installing amazon cloudwatch agent..."
Start-Process C:\packer-temp\amazon-cloudwatch-agent.msi -Wait

Write-Output "Setting amazon cloudwatch agent start type to delayed-auto..."
sc.exe config AmazonCloudWatchAgent start= delayed-auto
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Copying amazon cloudwatch agent config..."
Copy-Item -Path C:\packer-temp\conf\cloudwatch-agent\amazon-cloudwatch-agent.json -Destination C:\ProgramData\Amazon\AmazonCloudWatchAgent

Write-Output "Starting amazon cloudwatch agent..."
& 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a fetch-config -m ec2 -c file:C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json -s
