$ErrorActionPreference = 'Stop'

Write-Host "=== Enabling Windows Containers feature ==="

Install-WindowsFeature -Name Containers -IncludeAllSubFeature -ErrorAction Stop

Write-Host "Containers feature is installed, rebooting in 5s"
Start-Sleep -Seconds 5
Restart-Computer -Force