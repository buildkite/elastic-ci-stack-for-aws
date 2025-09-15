$ErrorActionPreference = "Stop"

Write-Output "Configuring docker cleanup"

$DockerGcSchedule = if ($env:DOCKER_GC_SCHEDULE) { $env:DOCKER_GC_SCHEDULE } else { "hourly" }
$DockerGcPruneUntil = if ($env:DOCKER_GC_PRUNE_UNTIL) { $env:DOCKER_GC_PRUNE_UNTIL } else { "4h" }
$DockerGcPruneImages = if ($env:DOCKER_GC_PRUNE_IMAGES) { $env:DOCKER_GC_PRUNE_IMAGES } else { "false" }
$DockerGcPruneVolumes = if ($env:DOCKER_GC_PRUNE_VOLUMES) { $env:DOCKER_GC_PRUNE_VOLUMES } else { "false" }

if ($DockerGcPruneUntil -notmatch '^[0-9]+[smhd]$') {
    Write-Warning "time format not expected: $DockerGcPruneUntil"
    Write-Warning "use format like 4h, 30m, 1d"
}

switch ($DockerGcSchedule) {
    { $_ -in @("hourly", "daily", "weekly", "monthly") } { break }
    { $_ -match '[0-9]+' } { break }
    default {
        Write-Warning "time format not expected - $DockerGcSchedule"
        Write-Warning "use hourly, daily, weekly, monthly"
    }
}

Write-Output "Schedule: $DockerGcSchedule"
Write-Output "Prune older than: $DockerGcPruneUntil"
Write-Output "Cleaning all images: $DockerGcPruneImages"
Write-Output "Volumes: $DockerGcPruneVolumes"

$dockerGcScript = @"
# Stop script execution when a non-terminating error occurs
`$ErrorActionPreference = "Stop"

# Log to the main log file
`$logFile = "C:\buildkite-agent\elastic-stack.log"
Add-Content -Path `$logFile -Value "`$(Get-Date): Docker cleanup starting"

`$TimeFilter = "--filter until=$DockerGcPruneUntil"

Add-Content -Path `$logFile -Value "Cleaning networks and containers"
docker network prune --force `$TimeFilter
docker container prune --force `$TimeFilter

if ("$DockerGcPruneImages" -eq "true") {
    Add-Content -Path `$logFile -Value "Cleaning all images"
    docker image prune --all --force `$TimeFilter
} else {
    Add-Content -Path `$logFile -Value "Cleaning dangling images only"
    docker image prune --force `$TimeFilter
}

if ("$DockerGcPruneVolumes" -eq "true") {
    Add-Content -Path `$logFile -Value "Cleaning volumes"
    docker volume prune --force `$TimeFilter
}

Add-Content -Path `$logFile -Value "`$(Get-Date): Docker cleanup completed"
"@

$dockerGcScript | Out-File -FilePath "C:\buildkite-agent\bin\docker-gc.ps1" -Encoding UTF8

$taskName = "DockerGC"

$trigger = switch ($DockerGcSchedule) {
    "hourly" { New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365) }
    "daily" { New-ScheduledTaskTrigger -Daily -At "2:00AM" }
    "weekly" { New-ScheduledTaskTrigger -Weekly -At "2:00AM" -DaysOfWeek Sunday }
    "monthly" { New-ScheduledTaskTrigger -Weekly -At "2:00AM" -WeeksInterval 4 -DaysOfWeek Sunday }
    default { New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365) }
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File C:\buildkite-agent\bin\docker-gc.ps1 >> C:\buildkite-agent\elastic-stack.log 2>&1"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Write-Output "creating scheduled task"
try {
    Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -Force | Out-Null
    Write-Output "scheduled task created successfully"
} catch {
    Write-Warning "failed to create scheduled task: $_"
    Write-Warning "retrying in 5 seconds..."
    Start-Sleep -Seconds 5
    try {
        Register-ScheduledTask -TaskName $taskName -Trigger $trigger -Action $action -Settings $settings -Force | Out-Null
        Write-Output "scheduled task created successfully on retry"
    } catch {
        Write-Warning "failed to create scheduled task twice, skipping timer setup"
        return
    }
}

Write-Output "Docker GC Cleanup configured"
Write-Output "Schedule: $DockerGcSchedule"
Write-Output "Prune older than: $DockerGcPruneUntil"
if ($DockerGcPruneImages -eq "true") {
    Write-Output "Will clean all images"
} else {
    Write-Output "Will clean dangling images only"
}
if ($DockerGcPruneVolumes -eq "true") {
    Write-Output "Will clean volumes"
} else {
    Write-Output "Volumes left alone"
}

Write-Output "Restarting Docker service..."
try {
    Restart-Service docker
    Write-Output "Docker service restarted successfully"
} catch {
    Write-Warning "Failed to restart Docker service: $_"
    Write-Warning "Continuing without Docker restart..."
}
