$ErrorActionPreference = 'Stop'
# Run manually: pwsh -NoProfile -File tests/windows/test-termination.ps1
# Real child processes; IMDS, AWS responses, transcript logging and shutdown are simulated.
# This does not replace Windows PowerShell 5.1/NSSM integration validation.
$program = Join-Path $PSScriptRoot '../../packer/windows/stack/conf/buildkite-agent/scripts/terminate-instance.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) "termination-$([guid]::NewGuid())"
New-Item -ItemType Directory $scratch | Out-Null
$fixture = Join-Path $scratch 'aws.ps1'
$env:TERMINATION_TEST_CALLS = Join-Path $scratch 'calls'
$env:TERMINATION_TEST_COMPLETED = Join-Path $scratch 'completed'
$powershell = (Get-Process -Id $PID).Path
Set-Content $fixture @'
Add-Content $env:TERMINATION_TEST_CALLS ($args -join ' ')
if ($args[0] -ne 'autoscaling' -or $args[[array]::IndexOf($args, '--instance-id') + 1] -ne 'i-test' -or $args[[array]::IndexOf($args, '--region') + 1] -ne 'us-east-1') {
    throw 'Incorrect Auto Scaling request'
}
$decrement = $args -contains '--should-decrement-desired-capacity'
if ($env:TERMINATION_TEST_CASE -eq 'timeout' -or ($env:TERMINATION_TEST_CASE -eq 'first-timeout' -and $decrement)) {
    Start-Sleep -Seconds 12
    Add-Content $env:TERMINATION_TEST_COMPLETED 'A timed-out command was allowed to complete'
    exit 1
}
if ($env:TERMINATION_TEST_CASE -eq 'success') { 'termination accepted'; exit 0 }
if ($env:TERMINATION_TEST_CASE -eq 'first-timeout' -and -not $decrement) { exit 0 }
if ($env:TERMINATION_TEST_CASE -eq 'minsize' -and -not $decrement) { exit 0 }
if ($env:TERMINATION_TEST_CASE -eq 'unhealthy' -and $args[1] -eq 'set-instance-health') { exit 0 }
if ($env:TERMINATION_TEST_CASE -eq 'transient') {
    if (@(Get-Content $env:TERMINATION_TEST_CALLS).Count -gt 1) { exit 0 }
    [Console]::Error.WriteLine('An error occurred (Throttling) when calling TerminateInstanceInAutoScalingGroup')
} else {
    # More than a pipe buffer of stderr must not deadlock the timeout handling.
    if ($env:TERMINATION_TEST_CASE -eq 'failure') { [Console]::Error.WriteLine('x' * 131072) }
    [Console]::Error.WriteLine('An error occurred (ValidationError) when calling TerminateInstanceInAutoScalingGroup')
}
exit 1
'@

function Start-Transcript { param($Path, [switch]$Append) }
function Stop-Transcript {}
function Invoke-WebRequest {
    param([Parameter(Position=0)]$Uri, [switch]$UseBasicParsing, $TimeoutSec, $Method, $Headers)
    if ($Uri -like '*/api/token') { return @{Content='token'} }
    if ($Uri -like '*/instance-id') { return @{Content='i-test'} }
    return @{Content='us-east-1'}
}
function shutdown { $testState.shutdownRequested = $true; $global:LASTEXITCODE = 0 }
# Substitute only the external executable. The production wait/kill logic still
# controls a real process, including its stdout/stderr and exit status.
function Start-Process {
    param($FilePath, $ArgumentList, $RedirectStandardOutput, $RedirectStandardError, [switch]$PassThru, [switch]$NoNewWindow)
    Microsoft.PowerShell.Management\Start-Process -FilePath $powershell `
        -ArgumentList (@('-NoProfile', '-NonInteractive', '-File', "`"$fixture`"") + $ArgumentList) `
        -RedirectStandardOutput $RedirectStandardOutput -RedirectStandardError $RedirectStandardError -PassThru
}
# The unchanged script invokes AWS directly; exercise that path for the red run.
function aws {
    & $powershell -NoProfile -NonInteractive -File $fixture @args
    $global:LASTEXITCODE = $LASTEXITCODE
}

try {
    foreach ($case in @('timeout', 'first-timeout', 'success', 'minsize', 'transient', 'unhealthy', 'failure')) {
        $env:TERMINATION_TEST_CASE = $case
        Remove-Item $env:TERMINATION_TEST_CALLS, $env:TERMINATION_TEST_COMPLETED -ErrorAction SilentlyContinue
        $testState = @{shutdownRequested = $false}
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $output = (& $program 2>&1 | Out-String)
        if (Test-Path $env:TERMINATION_TEST_COMPLETED) { throw "Stalled AWS process was not stopped: $case" }
        if ($timer.Elapsed.TotalSeconds -ge 55) { throw "Shutdown hook exceeded its safe runtime: $case" }
        if ($testState.shutdownRequested -ne ($case -in @('timeout', 'failure'))) { throw "Wrong shutdown outcome: $case`n$output" }
        if ($case -eq 'timeout' -and $output -notmatch 'timed out') { throw 'Missing timeout diagnostic' }
        if ($case -eq 'failure' -and $output -notmatch 'ValidationError') { throw 'AWS error diagnostic was lost' }
        $calls = @(Get-Content $env:TERMINATION_TEST_CALLS)
        if ($case -eq 'success' -and $calls.Count -ne 1) { throw 'Successful termination invoked fallbacks' }
        if ($case -eq 'transient' -and ($calls.Count -ne 2 -or $calls[-1] -notmatch '--should-decrement-desired-capacity')) { throw 'Transient error did not recover with capacity decrement' }
        if ($case -in @('first-timeout', 'minsize') -and ($calls.Count -ne 2 -or $calls[-1] -notmatch '--no-should-decrement-desired-capacity')) { throw "Termination did not recover without decrement: $case" }
        if ($case -in @('timeout', 'unhealthy', 'failure') -and ($calls.Count -ne 3 -or $calls[-1] -notmatch 'set-instance-health .*--health-status Unhealthy')) { throw "Instance health fallback was skipped: $case" }
        Write-Host "PASS: $case ($([math]::Round($timer.Elapsed.TotalSeconds, 1))s)"
    }
} finally {
    Remove-Item $scratch -Recurse -Force
    Remove-Item Env:TERMINATION_TEST_CASE, Env:TERMINATION_TEST_CALLS, Env:TERMINATION_TEST_COMPLETED
}
