# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Installing docker..."
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
.\install-docker-ce.ps1
