$ErrorActionPreference = 'Stop'
# Run manually: pwsh -NoProfile -File tests/windows/test-winrm-userdata.ps1
# Use a fresh process: this harness mocks Windows-only commands; not wired into CI.
$source = Get-Content (Join-Path $PSScriptRoot '../../packer/windows/shared/scripts/ec2-userdata.ps1') -Raw
$body = ($source -replace '(?s)^.*?<powershell>\s*', '') -replace '(?s)</powershell>.*$', ''
$tokens = $null; $parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($body, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
$program = [scriptblock]::Create($body)
$env:ProgramData = [System.IO.Path]::GetTempPath()
function Start-Transcript { param($Path, [switch]$Force) }
function Stop-Transcript {}
function Set-Service { param($Name,$StartupType) }
function Start-Service { param($Name) }
function Invoke-RestMethod {
  param([switch]$UseBasicParsing,$Method,$Uri,$Headers,$TimeoutSec)
  $script:metadataCalls++
  if ($script:transient -and $script:metadataCalls -eq 1) { throw 'mock transient failure' }
  if ($script:identityFails) { throw 'mock metadata failure' }
  if ($Uri.EndsWith('/api/token')) { return 'mock-token' }
  return $script:metadataId
}
function Start-Sleep { param($Seconds) }
function Test-Path { param($Path) return ($script:marker -ne '') }
function Get-Content { param($Path,[switch]$Raw) return $script:marker }
function Get-ChildItem {
  param($Path)
  if ($Path -eq 'WSMan:\Localhost\Listener') {
    return [pscustomobject]@{ Keys=@('Transport=HTTPS'); PSPath='mock-listener' }
  }
  return @(
    [pscustomobject]@{Name='CertificateThumbprint';Value='mock-thumbprint'},
    [pscustomobject]@{Name='Enabled';Value='true'},
    [pscustomobject]@{Name='Port';Value='5986'}
  )
}
function Get-Item {
  param($Path,$ErrorAction)
  [pscustomobject]@{HasPrivateKey=$script:validCert;NotBefore=(Get-Date).AddDays(-1);NotAfter=(Get-Date).AddDays(1)}
}
function Remove-Item { param($Path,[switch]$Recurse,$ErrorAction) $script:removed++ }
function New-SelfSignedCertificate { param($DnsName,$CertStoreLocation) [pscustomobject]@{Thumbprint='new-thumbprint'} }
function New-Item {
  param($Path,$Transport,$Address,$CertificateThumbPrint,[switch]$Force,$ItemType)
  if ($Transport -eq 'HTTPS') { $script:created++ }
}
function Set-Content { param($Path,$Value,$Encoding) $script:written=$Value }
function hostname { 'MOCK-HOST' }
function winrm {
  if (($args -join ' ') -match 'SkipCACheck|SkipCNCheck') {
    $global:LASTEXITCODE = 1
  } else {
    $global:LASTEXITCODE = $script:nativeExit
  }
}
function netsh { $global:LASTEXITCODE = 0 }
$cases = @(
  @{Name='same instance preserves';Marker='i-0123456789abcdef0';Valid=$true;Fails=$false;Exit=0;Expected=0;Throws=$false},
  @{Name='transient metadata failure retries';Marker='i-0123456789abcdef0';Transient=$true;Valid=$true;Fails=$false;Exit=0;Expected=0;Throws=$false},
  @{Name='whitespace identity preserves';Marker='i-0123456789abcdef0';Id="i-0123456789abcdef0`n";Valid=$true;Fails=$false;Exit=0;Expected=0;Throws=$false},
  @{Name='malformed identity leaves listener untouched';Marker='';Id='invalid';Valid=$true;Fails=$false;Exit=0;Expected=0;Throws=$true},
  @{Name='cloned instance recreates';Marker='i-fedcba98765432100';Valid=$true;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='missing marker recreates';Marker='';Valid=$true;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='invalid certificate recreates';Marker='i-0123456789abcdef0';Valid=$false;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='metadata failure leaves listener untouched';Marker='';Valid=$true;Fails=$true;Exit=0;Expected=0;Throws=$true},
  @{Name='native failure does not write marker';Marker='';Valid=$true;Fails=$false;Exit=1;Expected=1;Throws=$true}
)
foreach ($case in $cases) {
  $script:metadataCalls=0; $script:transient=$case.Transient
  $script:metadataId=if ($case.ContainsKey('Id')) { $case.Id } else { 'i-0123456789abcdef0' }
  $script:marker=$case.Marker; $script:validCert=$case.Valid; $script:identityFails=$case.Fails; $script:nativeExit=$case.Exit
  $script:removed=0; $script:created=0; $script:written=''; $threw=$false
  try { & $program } catch { $threw=$true }
  if ($threw -ne $case.Throws -or $script:created -ne $case.Expected -or $script:removed -ne $case.Expected) { throw "Failed: $($case.Name)" }
  if ($case.Throws -and $script:written) { throw "Marker written after failure: $($case.Name)" }
  if (!$case.Throws -and $case.Expected -and $script:written -ne 'i-0123456789abcdef0') { throw "Missing marker: $($case.Name)" }
  Write-Host "PASS: $($case.Name)"
}
Write-Host 'PowerShell parser and nine mocked behavior scenarios passed. Real Windows/WinRM validation remains required.'
