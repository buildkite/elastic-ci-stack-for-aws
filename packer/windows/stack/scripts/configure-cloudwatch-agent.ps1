# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Configuring CloudWatch agent..."

Write-Output "Copying amazon cloudwatch agent config..."
Copy-Item -Path C:\packer-temp\conf\cloudwatch-agent\amazon-cloudwatch-agent.json -Destination C:\ProgramData\Amazon\AmazonCloudWatchAgent

Write-Output "Starting amazon cloudwatch agent..."
& 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a fetch-config -m ec2 -c file:C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json -s