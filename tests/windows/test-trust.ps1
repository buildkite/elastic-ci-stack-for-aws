$ErrorActionPreference = 'Stop'
# Run manually: pwsh -NoProfile -File tests/windows/test-trust.ps1
# Use a fresh process: Windows file discovery and the Disallowed store are simulated.
# PEM parsing, fingerprints, chain checks, filtering and writes use the real script.
$program = Join-Path $PSScriptRoot '../../packer/trust/check-trust.ps1'
$safe = (Get-Content -Raw (Join-Path $PSScriptRoot '../trust/isrg-root-x1.crt')).Trim()
$affected = (Get-ChildItem (Join-Path $PSScriptRoot '../../packer/trust/roots/*.crt') |
    ForEach-Object { (Get-Content -Raw $_.FullName).Trim() }) -join "`n"
$mixed = "$affected`n$safe`n"
$scratch = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.amp/in/trust-$([guid]::NewGuid())"))
# The host may trust these public roots. Give the real chain an empty custom
# trust store before Build, without rewriting or replacing the script under test.
$storeBreakpoint = Set-PSBreakpoint -Script $program -Variable chain -Mode Read -Action {
    $chain.ChainPolicy.TrustMode = 'CustomRootTrust'
}

function Get-ChildItem {
    param($Path)
    if ($Path.StartsWith('C:\Program Files\')) {
        $Path = Join-Path $bundleRoot ($Path.Substring(17).Replace('\', '/'))
    }
    Microsoft.PowerShell.Management\Get-ChildItem -Path $Path
}
function Get-Item {
    param($Path)
    if ($Path.StartsWith('C:\Program Files\')) {
        $Path = Join-Path $bundleRoot ($Path.Substring(17).Replace('\', '/'))
    }
    Microsoft.PowerShell.Management\Get-Item -Path $Path
}
function Test-Path {
    param($Path)
    if ($Path.StartsWith('Cert:\LocalMachine\Disallowed\')) { return $true }
    Microsoft.PowerShell.Management\Test-Path -Path $Path
}

$cases = @(
    @{Name='legacy mingw64 sanitizes';Layout='mingw64';Sanitize=$true},
    @{Name='current ucrt64 sanitizes';Layout='ucrt64';Sanitize=$true},
    @{Name='MSYS rejects affected roots';Layout='ucrt64';Error='Affected root in';Target='msys'},
    @{Name='missing native fails despite MSYS bundle';Layout='ucrt64';Missing='native';Error='Missing native Git CA bundle'},
    @{Name='missing MSYS fails';Layout='ucrt64';Missing='msys';Error='Cannot find path';Target='msys'}
)
try {
    foreach ($case in $cases) {
        $bundleRoot = Join-Path $scratch $case.Name
        $paths = @{
            native = "Git/$($case.Layout)/etc/ssl/certs/ca-bundle.crt"
            msys = 'Git/usr/ssl/certs/ca-bundle.crt'
            aws = 'Amazon/AWSCLIV2/awscli/botocore/cacert.pem'
        }
        $before = @{}
        foreach ($key in @($paths.Keys)) {
            $path = Join-Path $bundleRoot $paths[$key]
            $paths[$key] = $path
            New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
            if ($case.Missing -eq $key) { continue }
            $pem = if ($case.Sanitize -or $key -eq 'msys') { $mixed } else { "$safe`n" }
            [IO.File]::WriteAllText($path, $pem, [Text.Encoding]::ASCII)
            $before[$path] = $pem
        }
        $failure = $null
        try { & $program -Sanitize:([bool]$case.Sanitize) | Out-Null }
        catch { $failure = $_.Exception.Message }
        if ($case.Error) {
            if (-not $failure -or $failure -notmatch $case.Error) {
                throw "Failed: $($case.Name); expected '$($case.Error)', got '$failure'"
            }
            if ($case.Target -and -not $failure.Contains($paths[$case.Target])) {
                throw "Failed: $($case.Name); rejected wrong bundle: $failure"
            }
        } elseif ($failure) { throw "Failed: $($case.Name); $failure" }
        foreach ($path in $before.Keys) {
            $actual = [IO.File]::ReadAllText($path)
            $expected = if ($case.Sanitize) { "$safe`n" } else { $before[$path] }
            if ($actual -cne $expected) {
                throw "Failed: $($case.Name); unexpected bundle contents: $path"
            }
        }
        Write-Host "PASS: $($case.Name)"
    }
} finally {
    Remove-PSBreakpoint $storeBreakpoint
    if (Test-Path $scratch) { Remove-Item -Recurse -Force $scratch }
}
Write-Host "All $($cases.Count) trust scenarios passed. Real Windows store/discovery validation remains required."
