Start-Transcript -path C:\buildkite-agent\terminate-instance.log -append
$Stopwatch = [Diagnostics.Stopwatch]::StartNew()

# NSSM kills this hook after 60s. Bound metadata requests and whole AWS processes
# (including startup and DNS), leaving time for the shutdown fallback.
$Env:AWS_RETRY_MODE = "standard"
$Env:AWS_MAX_ATTEMPTS = "2"
$AwsTimeouts = @("--cli-connect-timeout", "2", "--cli-read-timeout", "3")

function Invoke-AutoScaling {
  param([string[]]$AwsArguments)

  # Redirect to files so a full stdout/stderr pipe cannot block the process.
  $Stdout = [IO.Path]::GetTempFileName()
  $Stderr = [IO.Path]::GetTempFileName()
  $Process = $null
  try {
    $Process = Start-Process -FilePath aws.exe `
      -ArgumentList (@("autoscaling") + $AwsArguments + @("--region", $Region) + $AwsTimeouts) `
      -RedirectStandardOutput $Stdout -RedirectStandardError $Stderr -NoNewWindow -PassThru -ErrorAction Stop
    # Windows PowerShell 5.1 needs a cached handle to read ExitCode after waiting.
    $null = $Process.Handle
    if (-not $Process.WaitForExit(10000)) {
      $Process.Kill()
      $Process.WaitForExit()
      return [pscustomobject]@{ ExitCode = 1; Output = "AWS command timed out after 10s: $($AwsArguments -join ' ')" }
    }
    $Output = ((Get-Content $Stdout -Raw), (Get-Content $Stderr -Raw)) -join "`n"
    return [pscustomobject]@{ ExitCode = $Process.ExitCode; Output = $Output.Trim() }
  } catch {
    return [pscustomobject]@{ ExitCode = 1; Output = $_.Exception.Message }
  } finally {
    if ($Process) { $Process.Dispose() }
    Remove-Item $Stdout, $Stderr -ErrorAction SilentlyContinue
  }
}

$Token = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content

$InstanceId = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/placement/region).content

Write-Output "$(Get-Date) terminate-instance: requesting instance termination..."

# Retry errors that clear on their own, such as throttling when many instances
# scale in together, so the ASG doesn't launch an unnecessary replacement.
# Other errors, such as the ValidationError at minSize, fall through
# immediately. Stop retrying after 15s to leave time for the fallbacks below.
$Backoff = 1
while ($true) {
  $Result = Invoke-AutoScaling -AwsArguments @("terminate-instance-in-auto-scaling-group", "--instance-id", $InstanceId, "--should-decrement-desired-capacity")
  if ($Result.ExitCode -eq 0) { break }
  Write-Output "$(Get-Date) terminate-instance: termination with capacity decrement failed: $($Result.Output)"
  if ($Result.Output -notmatch '\((Throttling|ResourceContention|ScalingActivityInProgress)\)' -or $Stopwatch.Elapsed.TotalSeconds + $Backoff -gt 15) { break }
  Write-Output "$(Get-Date) terminate-instance: retrying in ${Backoff}s..."
  Start-Sleep -Seconds $Backoff
  $Backoff *= 2
}

# The agent service does not restart after it exits, so the instance must be
# replaced if it can't be removed. If the ASG can't decrement (for example,
# we're already at minSize), terminate without decrementing so the ASG
# launches a replacement. If that also fails, mark the instance unhealthy so
# the ASG replaces it despite scale-in protection.
if ($Result.ExitCode -eq 0) {
  Write-Output $Result.Output
  Write-Output "$(Get-Date) terminate-instance: terminating instance..."
} else {
  Write-Output "$(Get-Date) terminate-instance: terminating without decrement..."
  $Result = Invoke-AutoScaling -AwsArguments @("terminate-instance-in-auto-scaling-group", "--instance-id", $InstanceId, "--no-should-decrement-desired-capacity")
  Write-Output $Result.Output

  if ($Result.ExitCode -eq 0) {
    Write-Output "$(Get-Date) terminate-instance: terminating instance (ASG will launch a replacement)..."
  } else {
    Write-Output "$(Get-Date) terminate-instance: termination failed, marking instance as unhealthy"
    $Result = Invoke-AutoScaling -AwsArguments @("set-instance-health", "--instance-id", $InstanceId, "--health-status", "Unhealthy")
    Write-Output $Result.Output

    # Last resort: the agent won't restart, so shut down and let the ASG
    # replace the stopped instance despite scale-in protection.
    if ($Result.ExitCode -ne 0) {
      Write-Output "$(Get-Date) terminate-instance: could not mark instance unhealthy, shutting down"
      shutdown /s /f /t 0
      Write-Output "$(Get-Date) terminate-instance: shutdown exited with code $lastexitcode"
      Stop-Transcript
      exit 0
    }
  }
}

Stop-Transcript
