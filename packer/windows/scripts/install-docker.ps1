# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Installing docker..."
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
.\install-docker-ce.ps1
docker --version

$docker_compose_version="1.29.2"
Write-Output "Installing docker-compose..."
choco install -y docker-compose --version $docker_compose_version
If ($lastexitcode -ne 0) { Exit $lastexitcode }
