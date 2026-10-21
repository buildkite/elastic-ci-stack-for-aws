$ErrorActionPreference = 'Stop'

# Run in a separate provisioner so a lost WinRM connection or an early exit from
# the upstream installer cannot bypass validation in the installer's process.
Write-Output '=== Validating Docker installation ==='
$dockerDir = Join-Path $env:ProgramFiles 'Docker'
foreach ($binary in @('docker.exe', 'dockerd.exe', 'docker-credential-ecr-login.exe')) {
  $path = Join-Path $dockerDir $binary
  if (-not (Test-Path -Path $path -PathType Leaf)) {
    throw "Docker installation is incomplete: missing $path"
  }
}

$dockerService = Get-Service -Name docker -ErrorAction Stop
if ($dockerService.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
  throw "Docker service is not running: $($dockerService.Status)"
}

# Query both client and server; --version alone does not check the daemon/API.
& "$dockerDir\docker.exe" version
if ($LASTEXITCODE -ne 0) {
  throw "Docker client/server validation failed with exit code $LASTEXITCODE"
}

Write-Output 'Docker installation and client/server API validated successfully.'
