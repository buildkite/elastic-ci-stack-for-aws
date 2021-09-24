# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$lifecycled_version = "v3.2.0"

Write-Output "Installing lifecycled ${lifecycled_version}..."

New-Item -ItemType directory -Path C:\lifecycled\bin

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -OutFile C:\lifecycled\bin\lifecycled.exe https://github.com/buildkite/lifecycled/releases/download/${lifecycled_version}/lifecycled-windows-amd64.exe

Write-Output "Configure lifecycled to run on startup..."
nssm install lifecycled C:\lifecycled\bin\lifecycled.exe
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set lifecycled AppStdout C:\lifecycled\lifecycled.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set lifecycled AppStderr C:\lifecycled\lifecycled.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }
