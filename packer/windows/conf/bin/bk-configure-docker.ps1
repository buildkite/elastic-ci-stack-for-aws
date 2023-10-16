## Configures docker before system starts

Set-PSDebug -Trace 2

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$dockerd_config = "C:\ProgramData\docker\config\daemon.json"
$restart_docker = "false"

If (! (Test-Path $dockerd_config)) {
  Set-Content -Path $dockerd_config -Value "{}"
}

# Set experimental in config
If ($Env:DOCKER_EXPERIMENTAL -eq "true") {
  Get-Content -Path $dockerd_config | jq '.experimental=true' | Set-Content -Path $dockerd_config
  $restart_docker = "true"
}

If ($restart_docker -eq "true") {
  Restart-Service docker
}

Set-PSDebug -Off
