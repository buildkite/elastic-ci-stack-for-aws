Start-Transcript -path C:\buildkite-agent\check-agent-health.log -append

Write-Output "$(Get-Date) check-agent-health: starting health check..."

$MinUptimeSeconds = if ($Env:BUILDKITE_AGENT_HEALTH_CHECK_MIN_UPTIME) {
  [int]$Env:BUILDKITE_AGENT_HEALTH_CHECK_MIN_UPTIME
} else {
  600
}

$Uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
$UptimeSeconds = [int]$Uptime.TotalSeconds

if ($UptimeSeconds -lt $MinUptimeSeconds) {
  Write-Output "$(Get-Date) check-agent-health: uptime ${UptimeSeconds}s < ${MinUptimeSeconds}s, skipping (boot grace period)"
  Stop-Transcript
  exit 0
}

$TerminateProcess = Get-Process -Name "terminate-instance*" -ErrorAction SilentlyContinue
if ($TerminateProcess) {
  Write-Output "$(Get-Date) check-agent-health: terminate-instance already running, skipping"
  Stop-Transcript
  exit 0
}

function Mark-InstanceUnhealthy {
  Write-Output "$(Get-Date) check-agent-health: marking instance unhealthy..."

  $Token = (Invoke-WebRequest -UseBasicParsing -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content
  $InstanceId = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
  $Region = (Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

  aws autoscaling set-instance-health `
    --instance-id "$InstanceId" `
    --region "$Region" `
    --health-status Unhealthy

  Write-Output "$(Get-Date) check-agent-health: instance marked unhealthy"
}

$AgentStatus = nssm status buildkite-agent 2>&1
$AgentRunning = $AgentStatus -match "SERVICE_RUNNING"

if (-not $AgentRunning) {
  Write-Output "$(Get-Date) check-agent-health: agent not running (status: $AgentStatus)"
  Mark-InstanceUnhealthy
  Stop-Transcript
  exit 0
}

$AgentsPerInstance = if ($Env:BUILDKITE_AGENTS_PER_INSTANCE) {
  [int]$Env:BUILDKITE_AGENTS_PER_INSTANCE
} else {
  1
}

$UnhealthyWorkers = 0

for ($i = 1; $i -le $AgentsPerInstance; $i++) {
  try {
    $Response = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://127.0.0.1:9191/agent/$i" -ErrorAction Stop
  } catch {
    Write-Output "$(Get-Date) check-agent-health: worker $i health check failed"
    $UnhealthyWorkers++
  }
}

if ($UnhealthyWorkers -eq $AgentsPerInstance) {
  Write-Output "$(Get-Date) check-agent-health: all $AgentsPerInstance workers unhealthy"
  Mark-InstanceUnhealthy
  Stop-Transcript
  exit 0
}

$HealthyWorkers = $AgentsPerInstance - $UnhealthyWorkers
Write-Output "$(Get-Date) check-agent-health: health check passed ($HealthyWorkers/$AgentsPerInstance workers healthy)"

Stop-Transcript
