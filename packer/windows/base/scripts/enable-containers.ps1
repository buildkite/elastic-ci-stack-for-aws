$ErrorActionPreference = 'Stop'

Write-Host "=== Enabling Windows Containers feature ==="

Install-WindowsFeature -Name Containers -IncludeAllSubFeature -ErrorAction Stop

# Packer's windows-restart provisioner owns the reboot and waits for WinRM.
# Rebooting here can leave the next provisioner using a stale connection.
Write-Host "Containers feature is installed; Packer will restart the machine."
