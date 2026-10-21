<persist>true</persist>
<powershell>
$ErrorActionPreference = 'Stop'
Start-Transcript -Path C:\Windows\Temp\ec2-userdata.log -Force
Write-Host "=== User Data: Configuring WinRM HTTPS w/ Self-Signed Cert ==="

# This marker survives an ordinary reboot, but contains the old instance ID in
# an AMI clone. Do not reuse a pre-Sysprep listener just because its certificate
# still appears valid. Require IMDSv2 identity before changing any listener.
$metadataUrl = 'http://169.254.169.254/latest'
$metadataToken = Invoke-RestMethod -UseBasicParsing -Method Put `
  -Uri "$metadataUrl/api/token" `
  -Headers @{ 'X-aws-ec2-metadata-token-ttl-seconds' = '60' } -TimeoutSec 30
$instanceId = Invoke-RestMethod -UseBasicParsing `
  -Uri "$metadataUrl/meta-data/instance-id" `
  -Headers @{ 'X-aws-ec2-metadata-token' = $metadataToken } -TimeoutSec 30
if ($instanceId -notmatch '^i-[0-9a-f]+$') {
  throw 'Could not determine the EC2 instance ID; refusing to replace the WinRM listener.'
}
$listenerStateDir = Join-Path $env:ProgramData 'Buildkite\Packer'
$listenerInstanceFile = Join-Path $listenerStateDir 'winrm-instance-id'
$listenerInstanceId = if (Test-Path $listenerInstanceFile) {
  ([string](Get-Content -Path $listenerInstanceFile -Raw)).Trim()
} else {
  ''
}

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
    if ($listenerInstanceId -eq $instanceId -and
        $enabled -eq 'true' -and $port -eq '5986' -and $thumbprint) {
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
  Write-Host 'Creating WinRM HTTPS listener for this instance; existing listener is inherited or unusable.'
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
  if ($LASTEXITCODE -ne 0) { throw "WinRM configuration failed with exit code $LASTEXITCODE" }
  winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
  if ($LASTEXITCODE -ne 0) { throw "WinRM configuration failed with exit code $LASTEXITCODE" }

  winrm set winrm/config/service/auth '@{Basic="true"}'
  if ($LASTEXITCODE -ne 0) { throw "WinRM configuration failed with exit code $LASTEXITCODE" }
  winrm set winrm/config/service '@{AllowUnencrypted="true"}'
  if ($LASTEXITCODE -ne 0) { throw "WinRM configuration failed with exit code $LASTEXITCODE" }

  winrm set winrm/config/client `
    '@{SkipCACheck="true"; SkipCNCheck="true"; TrustedHosts="*"}'
  if ($LASTEXITCODE -ne 0) { throw "WinRM configuration failed with exit code $LASTEXITCODE" }

  netsh advfirewall firewall add rule `
    name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
  if ($LASTEXITCODE -ne 0) { throw "WinRM firewall configuration failed with exit code $LASTEXITCODE" }
  netsh advfirewall firewall add rule `
    name="WinRM HTTPS" protocol=TCP dir=in localport=5986 action=allow

  # Write only after configuration succeeds. A missing/mismatched marker must
  # never cause an inherited listener to be accepted on the next boot.
  if ($LASTEXITCODE -ne 0) {
    throw "WinRM firewall configuration failed with exit code $LASTEXITCODE"
  }
  New-Item -Path $listenerStateDir -ItemType Directory -Force | Out-Null
  Set-Content -Path $listenerInstanceFile -Value $instanceId -Encoding ASCII
}

Write-Host "=== WinRM HTTPS configuration complete ==="
Stop-Transcript
</powershell>
