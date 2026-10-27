# Offline checks for Windows CryptoAPI and the separate Git / AWS CLI PEM stores.
param([switch]$SystemOnly, [switch]$Sanitize)
$ErrorActionPreference = 'Stop'
$blocked = @(
    'D7A7A0FB5D7E2731D771E9484EBCDEF71D5F0C3E0A2948782BC83EE0EA699EF4',
    '86A1ECBA089C4A8D3BBE2734C612BA341D813E043CF9E8A862CD5C57A36BBE6B',
    '7DD78D5F4F13459A83DFF9ABBBA62EDBAF6F2D102BF257FD712F4D9F2746ED8D',
    'F2EDAAFF3D9B701FB4D14C9F285F8C0BAD90FC3BCC1FA07D47F4718EDABA34A5'
)
function Read-Certificate($pem) {
    $body = $pem -replace '-----BEGIN CERTIFICATE-----|-----END CERTIFICATE-----|\s', ''
    return [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($body))
}
function Get-Fingerprint($cert) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($cert.RawData))).Replace('-', '') }
    finally { $sha.Dispose() }
}
$roots = @(Get-ChildItem "$PSScriptRoot\roots\*.crt")
if ($roots.Count -ne 4) { throw 'Expected four affected root certificates' }
foreach ($file in $roots) {
    $cert = Read-Certificate (Get-Content -Raw $file.FullName)
    if ((Get-Fingerprint $cert) -notin $blocked) { throw "Unexpected root certificate $file" }
    if (-not (Test-Path "Cert:\LocalMachine\Disallowed\$($cert.Thumbprint)")) {
        throw "Missing explicit Windows distrust: $($cert.Subject)"
    }
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $chain.ChainPolicy.RevocationMode = 'NoCheck'
    if ($chain.Build($cert)) { throw "Windows still trusts $($cert.Subject)" }
    $chain.Dispose()
}
Write-Output 'PASS: Windows explicit distrust of affected roots'
if ($SystemOnly) { return }

# Git 2.56 moved its native prefix from mingw64 to ucrt64. Check every
# installed native bundle, plus the separate bundle used by MSYS tools.
$gitBundles = @(Get-ChildItem 'C:\Program Files\Git\*\etc\ssl\certs\ca-bundle.crt')
if ($gitBundles.Count -lt 1) { throw 'Missing native Git CA bundle' }
$bundles = @(
    $gitBundles.FullName
    (Get-Item 'C:\Program Files\Git\usr\ssl\certs\ca-bundle.crt').FullName
    (Get-Item 'C:\Program Files\Amazon\AWSCLIV2\awscli\botocore\cacert.pem').FullName
)
foreach ($bundle in $bundles) {
    # Read/write the target (not a symlink). This preserves the unrelated roots
    # and avoids silently relying on an old embedded Mozilla trust snapshot.
    $certs = [regex]::Matches((Get-Content -Raw $bundle), '(?s)-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----')
    if ($certs.Count -lt 1) { throw "Empty PEM bundle: $bundle" }
    $safe = @()
    foreach ($match in $certs) {
        if ((Get-Fingerprint (Read-Certificate $match.Value)) -in $blocked) {
            if (-not $Sanitize) { throw "Affected root in $bundle" }
        } else { $safe += $match.Value }
    }
    if ($safe.Count -lt 1) { throw "No unaffected certificates remain in $bundle" }
    if ($Sanitize) { [IO.File]::WriteAllText($bundle, ($safe -join "`n") + "`n", [Text.Encoding]::ASCII) }
    Write-Output "PASS: $bundle; nonempty bundle, affected roots absent"
}
