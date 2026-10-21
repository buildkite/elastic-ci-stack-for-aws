$ErrorActionPreference = 'Stop'
# Run in a fresh PowerShell process: this harness mocks Windows-only commands.
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
  if ($script:identityFails) { throw 'mock metadata failure' }
  if ($Uri.EndsWith('/api/token')) { return 'mock-token' }
  return 'i-0123456789abcdef0'
}
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
function winrm { $global:LASTEXITCODE = $script:nativeExit }
function netsh { $global:LASTEXITCODE = 0 }
$cases = @(
  @{Name='same instance preserves';Marker='i-0123456789abcdef0';Valid=$true;Fails=$false;Exit=0;Expected=0;Throws=$false},
  @{Name='cloned instance recreates';Marker='i-fedcba98765432100';Valid=$true;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='missing marker recreates';Marker='';Valid=$true;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='invalid certificate recreates';Marker='i-0123456789abcdef0';Valid=$false;Fails=$false;Exit=0;Expected=1;Throws=$false},
  @{Name='metadata failure leaves listener untouched';Marker='';Valid=$true;Fails=$true;Exit=0;Expected=0;Throws=$true},
  @{Name='native failure does not write marker';Marker='';Valid=$true;Fails=$false;Exit=1;Expected=1;Throws=$true}
)
foreach ($case in $cases) {
  $script:marker=$case.Marker; $script:validCert=$case.Valid; $script:identityFails=$case.Fails; $script:nativeExit=$case.Exit
  $script:removed=0; $script:created=0; $script:written=''; $threw=$false
  try { & $program } catch { $threw=$true }
  if ($threw -ne $case.Throws -or $script:created -ne $case.Expected -or $script:removed -ne $case.Expected) { throw "Failed: $($case.Name)" }
  if ($case.Throws -and $script:written) { throw "Marker written after failure: $($case.Name)" }
  if (!$case.Throws -and $case.Expected -and $script:written -ne 'i-0123456789abcdef0') { throw "Missing marker: $($case.Name)" }
  Write-Host "PASS: $($case.Name)"
}
Write-Host 'PowerShell parser and six mocked behavior scenarios passed. Real Windows/WinRM validation remains required.'
