# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Stopping buildkite-agent gracefully"

Stop-Service -Verbose buildkite-agent

Write-Output "All buildkite-agent processes have stopped"
