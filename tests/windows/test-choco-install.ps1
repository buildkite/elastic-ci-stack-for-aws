$ErrorActionPreference = 'Stop'
# Run manually: pwsh -NoProfile -File tests/windows/test-choco-install.ps1
# Chocolatey outcomes and sleeps are simulated; the real retry script is used.
$program = Join-Path $PSScriptRoot '../../packer/windows/base/scripts/choco-install.ps1'
Set-Alias choco-install $program

function choco {
    if (($args -join ' ') -cne 'install -y git --version=2.56.0') {
        throw "Install arguments changed: $args"
    }
    $global:LASTEXITCODE = $case.Codes[$state.Attempts]
    $state.Attempts++
}
function Start-Sleep { param($Seconds) $state.Delays += $Seconds }

$cases = @(
    @{Name='transient failure then success'; Codes=@(1, 0); Delays=@(15)},
    @{Name='success on final attempt'; Codes=@(1, 1, 0); Delays=@(15, 30)},
    @{Name='exhausted attempts preserve final failure'; Codes=@(1, 7, -1); Delays=@(15, 30)}
)
# Chocolatey package-success and reboot statuses must not be retried or mapped to zero.
foreach ($code in @(0, 1605, 1614, 1641, 3010, 350, 1604)) {
    $cases += @{Name="status $code is returned immediately"; Codes=@($code); Delays=@()}
}

foreach ($case in $cases) {
    $state = @{Attempts=0; Delays=@()}
    $global:LASTEXITCODE = 99
    choco-install -y git --version=2.56.0
    if ($LASTEXITCODE -ne $case.Codes[-1] -or $state.Attempts -ne $case.Codes.Count -or
        ($state.Delays -join ',') -ne ($case.Delays -join ',')) {
        throw "Failed: $($case.Name); exit=$LASTEXITCODE, attempts=$($state.Attempts), delays=$($state.Delays)"
    }
    Write-Host "PASS: $($case.Name)"
}
Write-Host "All $($cases.Count) Chocolatey retry scenarios passed. Real Windows/Chocolatey validation remains required."
