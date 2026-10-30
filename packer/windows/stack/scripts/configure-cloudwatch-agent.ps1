# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Configuring CloudWatch agent..."

Write-Output "Copying amazon cloudwatch agent config..."
# fetch-config deletes its reserved amazon-cloudwatch-agent.json input. Keep a
# stack-owned source so bootstrap can apply log retention after image creation.
Copy-Item -Path C:\packer-temp\conf\cloudwatch-agent\amazon-cloudwatch-agent.json -Destination C:\ProgramData\Amazon\AmazonCloudWatchAgent\buildkite-cloudwatch-agent.json

Write-Output "Starting amazon cloudwatch agent..."
& 'C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1' -a fetch-config -m ec2 -c file:C:\ProgramData\Amazon\AmazonCloudWatchAgent\buildkite-cloudwatch-agent.json -s

# The base AMI sets the agent to manual start, so it wouldn't start on boot.
# Delay the start: during boot the agent can miss the 30s service start
# timeout, and nothing retries it. See
# https://repost.aws/knowledge-center/cloudwatch-startup-reboot-errors
Write-Output "Setting amazon cloudwatch agent start type to delayed automatic..."
sc.exe config AmazonCloudWatchAgent start= delayed-auto
if ($LASTEXITCODE -ne 0) { throw "Failed to set the amazon cloudwatch agent start type" }
