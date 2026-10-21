<persist>true</persist>
<powershell>
Start-Transcript -Path C:\Windows\Temp\ec2-userdata.log -Force
Write-Host "=== User Data: Configuring WinRM HTTPS w/ Self-Signed Cert ==="

Set-Service -Name WinRM -StartupType Automatic
Start-Service  WinRM

# This userdata runs after every reboot, including Packer's Containers reboot.
# Packer can reconnect before EC2Launch reaches this script. Replacing an already
# usable listener then interrupts the active provisioner, potentially silently.
$usableListener = $false
foreach ($listener in (Get-ChildItem WSMan:\Localhost\Listener)) {
  if ($listener.Keys -contains 'Transport=HTTPS') {
    $settings = Get-ChildItem $listener.PSPath
    $thumbprint = ($settings | Where-Object Name -eq 'CertificateThumbprint').Value
    $enabled = ($settings | Where-Object Name -eq 'Enabled').Value
    $port = ($settings | Where-Object Name -eq 'Port').Value
    if ($enabled -eq 'true' -and $port -eq '5986' -and $thumbprint) {
      $existingCert = Get-Item "Cert:\LocalMachine\My\$thumbprint" -ErrorAction SilentlyContinue
      if ($existingCert -and $existingCert.HasPrivateKey -and
          $existingCert.NotBefore -le (Get-Date) -and $existingCert.NotAfter -gt (Get-Date)) {
        $usableListener = $true
      }
    }
  }
}

if ($usableListener) {
  Write-Host 'Keeping existing WinRM HTTPS listener; no reconfiguration needed.'
} else {
  Remove-Item -Path WSMan:\Localhost\Listener\Listener* -Recurse -ErrorAction SilentlyContinue

  $cert = New-SelfSignedCertificate `
    -DnsName (hostname) `
    -CertStoreLocation Cert:\LocalMachine\My

  New-Item -Path WSMan:\LocalHost\Listener `
    -Transport HTTPS `
    -Address * `
    -CertificateThumbPrint $cert.Thumbprint `
    -Force

  winrm set winrm/config '@{MaxTimeoutms="1800000"}'
  winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

  winrm set winrm/config/service/auth '@{Basic="true"}'
  winrm set winrm/config/service '@{AllowUnencrypted="true"}'

  winrm set winrm/config/client `
    '@{SkipCACheck="true"; SkipCNCheck="true"; TrustedHosts="*"}'

  netsh advfirewall firewall add rule `
    name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
  netsh advfirewall firewall add rule `
    name="WinRM HTTPS" protocol=TCP dir=in localport=5986 action=allow
}

Write-Host "=== WinRM HTTPS configuration complete ==="
Stop-Transcript
</powershell>
