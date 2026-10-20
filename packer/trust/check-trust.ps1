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
if ($roots.Count -ne 4) { throw 'Expected four affected root fixtures' }
foreach ($file in $roots) {
    $cert = Read-Certificate (Get-Content -Raw $file.FullName)
    if ((Get-Fingerprint $cert) -notin $blocked) { throw "Unexpected root fixture $file" }
    if (-not (Test-Path "Cert:\LocalMachine\Disallowed\$($cert.Thumbprint)")) {
        throw "Missing explicit Windows distrust: $($cert.Subject)"
    }
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $chain.ChainPolicy.RevocationMode = 'NoCheck'
    if ($chain.Build($cert)) { throw "Windows still trusts $($cert.Subject)" }
    $chain.Dispose()
}
$control = Read-Certificate (Get-Content -Raw "$PSScriptRoot\isrg-root-x1.crt")
$chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
$chain.ChainPolicy.RevocationMode = 'NoCheck'
if (-not $chain.Build($control)) { throw 'Windows positive trust control failed' }
$chain.Dispose()
Write-Output 'PASS: Windows explicit distrust and positive control'
if ($SystemOnly) { return }

$openssl = 'C:\Program Files\Git\mingw64\bin\openssl.exe'
$bundles = @(
    'C:\Program Files\Git\mingw64\etc\ssl\certs\ca-bundle.crt',
    'C:\Program Files\Amazon\AWSCLIV2\awscli\botocore\cacert.pem'
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
    if ($Sanitize) { [IO.File]::WriteAllText($bundle, ($safe -join "`n") + "`n", [Text.Encoding]::ASCII) }
    $chains = @(Get-ChildItem "$PSScriptRoot\chains\*.pem")
    if ($chains.Count -ne 12) { throw 'Expected twelve incident chains' }
    # Capture native stderr without PowerShell 5 turning it into a terminating
    # NativeCommandError. Only issuer-not-found is an accepted negative result.
    foreach ($file in @((Get-Item "$PSScriptRoot\isrg-root-x1.crt")) + $chains) {
        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $result = & $openssl verify -attime 1792497600 -no-CApath -no-CAstore -CAfile $bundle -untrusted $file.FullName $file.FullName 2>&1
        $code = $LASTEXITCODE
        $ErrorActionPreference = $previousPreference
        if ($file.Name -eq 'isrg-root-x1.crt') {
            if ($code -ne 0) { throw "PEM positive control failed: $bundle $result" }
        } elseif ($code -eq 0 -or "$result" -notmatch 'error 20 ') {
            throw "Expected unknown issuer: $bundle $file $result"
        }
    }
    Write-Output "PASS: $bundle; incident roots absent, 12 chains rejected, positive control trusted"
}

# Expected negative OpenSSL checks must not become the provisioner exit status.
$global:LASTEXITCODE = 0
