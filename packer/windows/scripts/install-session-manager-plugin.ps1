# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$SESSION_MANAGER_PLUGIN_VERSION = "1.2.30.0"

Write-Output "Installing session-manager-plugin ${SESSION_MANAGER_PLUGIN_VERSION}..."
Invoke-WebRequest -OutFile C:\buildkite-agent\bin\SessionManagerPluginSetup.exe -Uri "https://s3.amazonaws.com/session-manager-downloads/plugin/${SESSION_MANAGER_PLUGIN_VERSION}/windows/SessionManagerPluginSetup.exe"
