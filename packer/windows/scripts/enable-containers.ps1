$ErrorActionPreference = "Stop"

Write-Output "Enabling Containers feature. We need to restart after this."
Add-WindowsFeature Containers
