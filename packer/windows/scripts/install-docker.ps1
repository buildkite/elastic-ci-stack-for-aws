# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$docker_compose_version="1.29.2"

Write-Output "Check that docker is installed"
docker --version

Write-Output "Installing docker-compose"
choco install -y docker-compose --version $docker_compose_version
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Installing jq"
choco install -y jq
If ($lastexitcode -ne 0) { Exit $lastexitcode }
