# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$AGENT_VERSION = "3.112.0"

# Source centralized version definitions
. "C:\Windows\Temp\versions.ps1"

Write-Output "Creating bin dir..."
if (-not (Test-Path C:\buildkite-agent\bin)) { New-Item -ItemType Directory -Path C:\buildkite-agent\bin -Force }

Write-Output 'Updating PATH'
$env:PATH = "C:\buildkite-agent\bin;" + $env:PATH
[Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)

Write-Output "Downloading buildkite-agent v${AGENT_VERSION} stable..."
Invoke-WebRequest -OutFile C:\buildkite-agent\bin\buildkite-agent-stable.exe -Uri "https://download.buildkite.com/agent/stable/${AGENT_VERSION}/buildkite-agent-windows-amd64.exe"
buildkite-agent-stable.exe --version
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Downloading buildkite-agent beta..."
Invoke-WebRequest -OutFile C:\buildkite-agent\bin\buildkite-agent-beta.exe -Uri "https://download.buildkite.com/agent/unstable/latest/buildkite-agent-windows-amd64.exe"
buildkite-agent-beta.exe --version
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Creating hooks dir..."
if (-not (Test-Path C:\buildkite-agent\hooks)) { New-Item -ItemType Directory -Path C:\buildkite-agent\hooks -Force }

Write-Output "Copying custom hooks..."
Copy-Item -Path C:\packer-temp\conf\buildkite-agent\hooks\* -Destination C:\buildkite-agent\hooks

Write-Output "Creating builds dir..."
if (-not (Test-Path C:\buildkite-agent\builds)) { New-Item -ItemType Directory -Path C:\buildkite-agent\builds -Force }

Write-Output "Creating git-mirrors dir..."
if (-not (Test-Path C:\buildkite-agent\git-mirrors)) { New-Item -ItemType Directory -Path C:\buildkite-agent\git-mirrors -Force }

Write-Output "Creating plugins dir..."
if (-not (Test-Path C:\buildkite-agent\plugins)) { New-Item -ItemType Directory -Path C:\buildkite-agent\plugins -Force }

Write-Output "Installing bk elastic stack bin files..."
Copy-Item -Path C:\packer-temp\conf\bin\bk-* -Destination C:\buildkite-agent\bin

Write-Output "Adding termination scripts..."
Copy-Item -Path C:\packer-temp\conf\buildkite-agent\scripts\terminate-instance.ps1 -Destination C:\buildkite-agent\bin
Copy-Item -Path C:\packer-temp\conf\buildkite-agent\scripts\stop-agent-gracefully.ps1 -Destination C:\buildkite-agent\bin

Write-Output "Copying built-in plugins..."
if (-not (Test-Path "C:\Program Files\Git\usr\local\buildkite-aws-stack\plugins")) { New-Item -ItemType Directory -Path "C:\Program Files\Git\usr\local\buildkite-aws-stack\plugins" -Force }
Copy-Item -Recurse -Path C:\packer-temp\plugins\* -Destination "C:\Program Files\Git\usr\local\buildkite-aws-stack\plugins\"
