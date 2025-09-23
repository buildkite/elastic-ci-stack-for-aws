# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

# https://docs.aws.amazon.com/systems-manager/latest/userguide/plugin-version-history.html
$SESSION_MANAGER_PLUGIN_VERSION = "1.2.707.0"

$targetDir = "C:\buildkite-agent\bin"
if (-not (Test-Path $targetDir)) {
  New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
}

$outFile = Join-Path $targetDir "SessionManagerPluginSetup.exe"
Write-Output "Installing session-manager-plugin ${SESSION_MANAGER_PLUGIN_VERSION} to $outFile..."
Invoke-WebRequest -OutFile $outFile -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/${SESSION_MANAGER_PLUGIN_VERSION}/windows/SessionManagerPluginSetup.exe"
