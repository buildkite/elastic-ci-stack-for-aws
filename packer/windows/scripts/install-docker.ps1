# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Installing docker..."
Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/microsoft/Windows-Containers/Main/helpful_tools/Install-DockerCE/install-docker-ce.ps1" -o install-docker-ce.ps1
.\install-docker-ce.ps1
docker --version

$docker_compose_version="2.35.1"
Write-Output "Installing docker-compose..."
choco install -y docker-compose --version $docker_compose_version
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Installing Amazon ECR credential helper..."
$ecr_cred_helper_version = "0.10.1"
$ecr_cred_helper_url = "https://amazon-ecr-credential-helper-releases.s3.us-east-2.amazonaws.com/$ecr_cred_helper_version/windows-amd64/docker-credential-ecr-login.exe"
$docker_plugins_dir = "${env:ProgramFiles}\Docker"
New-Item -ItemType Directory -Force -Path $docker_plugins_dir | Out-Null
Invoke-WebRequest -Uri $ecr_cred_helper_url -OutFile "$docker_plugins_dir\docker-credential-ecr-login.exe"
Write-Output "Amazon ECR credential helper v$ecr_cred_helper_version installed to $docker_plugins_dir"
