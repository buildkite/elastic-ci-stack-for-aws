$ErrorActionPreference = 'Stop'
# Run manually: pwsh -NoProfile -File tests/windows/test-bootstrap.ps1
# Real bootstrap and filesystem; Windows services, ACLs and AWS are simulated.
# This does not replace Windows/ASG integration tests.
$program = Join-Path $PSScriptRoot '../../packer/windows/stack/conf/bin/bk-install-elastic-stack.ps1'
$scratch = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "../../.amp/in/bootstrap-$([guid]::NewGuid())"))
New-Item -ItemType Directory -Path $scratch | Out-Null
New-PSDrive -Name C -PSProvider FileSystem -Root $scratch | Out-Null
class BkUserRights { static [void] Add([string]$sid, [string]$right) {} }

function Set-PSDebug { param($Trace, [switch]$Off) }
function Set-Content {
    param([Parameter(Position=0)]$Path, [Parameter(Position=1)]$Value, $Encoding)
    if ($testState.case.MarkerWriteFails -and $Path -eq 'C:\buildkite-agent\elastic-stack-bootstrap-status' -and $Value -eq 'Completed') {
        throw 'Could not persist completed bootstrap status'
    }
    Microsoft.PowerShell.Management\Set-Content @PSBoundParameters
}
function Start-Sleep { param($Seconds) $testState.slept += $Seconds; $testState.now = $testState.now.AddSeconds($Seconds) }
function Get-Date { $testState.now.LocalDateTime }
function Invoke-WebRequest {
    param([Parameter(Position=0)]$Uri, [switch]$UseBasicParsing, $Method, $Headers, $TimeoutSec)
    if ($testState.case.MetadataFails) { throw 'IMDS unavailable' }
    if ($Uri -like '*/api/token') { return @{Content='token'} }
    if ($Uri -like '*/dynamic/instance-identity/document') {
        $age = if ($testState.case.Expired) { 1000 } else { 30 }
        return @{Content=(@{instanceId='i-test'; region='us-east-1'; pendingTime=$testState.now.AddSeconds(-$age).ToString('o')} | ConvertTo-Json)}
    }
    return @{Content='i-test'}
}
function docker { $global:LASTEXITCODE=0; if ($args[0] -eq '--version') { 'Docker version 27.0.0, build test' } }
function powershell { $testState.configured++; $global:LASTEXITCODE=0 }
function nssm {
    $testState.configured++
    $global:LASTEXITCODE = if ($testState.case.NativeFails -and $args[0] -eq 'install') { 7 } else { 0 }
}
function icacls { $global:LASTEXITCODE=0 }
function Get-Service { param($Name,$ErrorAction) @{Status=[System.ServiceProcess.ServiceControllerStatus]::Running} }
function Start-Service {
    param($Name)
    if ($Name -eq 'buildkite-agent') {
        if ($testState.case.ServiceFails) { throw 'Service could not start' }
        $testState.agentStarted=$true
    }
}
function Restart-Service { param($Name) Start-Service $Name }
function New-LocalUser { param($Name,$Password,[switch]$PasswordNeverExpires) $testState.configured++ }
function Get-LocalUser { param($Name) @{SID=@{Value='S-1-5-21-test'}} }
function Add-LocalGroupMember { param($Group,$Member) }
function aws {
    $global:LASTEXITCODE=0
    if ($args[1] -eq 'describe-auto-scaling-instances') {
        if ($testState.case.DescribeDenied) {
            $global:LASTEXITCODE=1
            'An error occurred (AccessDenied)'
            return
        }
        return (@{AutoScalingInstances=@(@{AutoScalingGroupName='test-asg'; LifecycleState=$testState.state})} | ConvertTo-Json -Depth 4)
    }
    if ($args[1] -eq 'complete-lifecycle-action') {
        $result = $args[[array]::IndexOf($args, '--lifecycle-action-result') + 1]
        if ($result -eq 'CONTINUE') {
            $testState.continues++
            if ($testState.case.Expired) { throw 'Completion attempted after launch deadline' }
            if (-not $testState.agentStarted -and $testState.case.Marker -ne 'Completed') { throw 'CONTINUE before service startup' }
            if ((Get-Content C:\buildkite-agent\elastic-stack-bootstrap-status -Raw).Trim() -ne 'Completed') { throw 'CONTINUE before configuration completed' }
            if ($testState.case.ContinueFails) {
                $global:LASTEXITCODE=1
                'An error occurred (AccessDenied)'
                return
            }
            if ($testState.case.AlwaysThrottled -or ($testState.case.TransientContinue -and $testState.continues -eq 1)) {
                $global:LASTEXITCODE=1
                'An error occurred (Throttling)'
                return
            }
            $testState.state='InService'
            if ($testState.case.AmbiguousContinue -and $testState.continues -eq 1) {
                $global:LASTEXITCODE=1
                'Connection timed out after accepting CONTINUE'
            }
        } else { $testState.abandoned=$true; $testState.state='Terminating:Wait' }
    } elseif ($args[1] -eq 'set-instance-health') { $testState.unhealthy=$true }
}
function cfn-signal {
    $testState.signaled=$true
    if ($args[[array]::IndexOf($args, '--exit-code') + 1] -ne '0') { throw 'Failure signal sent to CloudFormation' }
    if ($testState.state -ne 'InService') { throw 'Success signaled before launch was confirmed' }
    $global:LASTEXITCODE = if ($testState.case.SignalFails) { 1 } else { 0 }
}

$env:AWS_REGION='us-east-1'
$env:BUILDKITE_STACK_NAME='test'
$env:BUILDKITE_STACK_DEPLOYED_BY='cloudformation'
$env:BUILDKITE_LAUNCH_HOOK_NAME='buildkite-agent-launch'
$env:BUILDKITE_LAUNCH_TIMEOUT='900'
$env:BUILDKITE_AGENT_RELEASE='stable'
$env:BUILDKITE_AGENT_TOKEN_PATH=''
$env:BUILDKITE_AGENT_SIGNING_KEY_PATH=''
$env:BUILDKITE_AGENT_VERIFICATION_KEY_PATH=''
$env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT=''
$env:BUILDKITE_ENV_FILE_URL=''
$env:EC2_LOG_RETENTION_DAYS=''

$cases = @(
    @{Name='healthy bootstrap completes configuration and launch'},
    @{Name='completed configuration is not recreated'; Marker='Completed'; State='InService'; Skip=$true},
    @{Name='completed configuration can finish a pending launch'; Marker='Completed'; Skip=$true},
    @{Name='metadata outage does not invalidate completed configuration'; Marker='Completed'; MetadataFails=$true; NoSignal=$true; Skip=$true},
    @{Name='incomplete pending launch is abandoned'; Marker='Started'; Abandon=$true; Fails=$true; Skip=$true},
    @{Name='invalid in-service configuration is replaced'; Marker='invalid'; State='InService'; Unhealthy=$true; Fails=$true; Skip=$true},
    @{Name='terminating incomplete instance is left alone'; Marker='Started'; State='Terminating:Wait'; Fails=$true; Skip=$true},
    @{Name='native configuration failure abandons launch'; NativeFails=$true; Abandon=$true; Fails=$true},
    @{Name='customer bootstrap nonzero exit abandons launch'; CustomerFails=$true; Abandon=$true; Fails=$true},
    @{Name='service startup failure abandons launch'; ServiceFails=$true; Abandon=$true; Fails=$true},
    @{Name='completed marker write failure leaves started agent alone'; MarkerWriteFails=$true; Fails=$true},
    @{Name='metadata failure leaves configuration incomplete'; MetadataFails=$true; Fails=$true; Skip=$true},
    @{Name='ambiguous accepted CONTINUE is reconciled'; AmbiguousContinue=$true},
    @{Name='transient CONTINUE failure retries successfully'; TransientContinue=$true},
    @{Name='persistent throttling stops within the remaining launch budget'; AlwaysThrottled=$true; NoSignal=$true; MaxSleep=870},
    @{Name='expired launch does not start a fresh retry budget'; Expired=$true; NoSignal=$true},
    @{Name='permanent describe denial does not consume the launch budget'; DescribeDenied=$true; NoSignal=$true; MaxSleep=1},
    @{Name='CONTINUE denial does not abandon a started agent'; ContinueFails=$true; NoSignal=$true},
    @{Name='CloudFormation delivery failure leaves completed agent running'; SignalFails=$true}
)
try {
    foreach ($case in $cases) {
        $testState=@{
            case=$case; now=[DateTimeOffset]::UtcNow
            state=$(if ($case.State) { $case.State } else { 'Pending:Wait' })
            configured=0; continues=0; slept=0; agentStarted=$false; abandoned=$false; unhealthy=$false; signaled=$false
        }
        Remove-Item C:\buildkite-agent -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory C:\buildkite-agent\bin -Force | Out-Null
        Set-Content C:\buildkite-agent\bin\buildkite-agent-stable.exe 'fixture'
        Set-Content C:\buildkite-agent\bin\bk-user-rights.ps1 '# BkUserRights stub is defined in this harness'
        Set-Content C:\buildkite-agent\bin\bk-fetch.ps1 'param($From, $To) Set-Content -Path $To -Value "exit 9"'
        $env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT = if ($case.CustomerFails) { 'https://example.invalid/bootstrap.ps1' } else { '' }
        Set-Content C:\buildkite-agent\buildkite-agent.cfg 'original configuration'
        if ($case.Marker) { Set-Content C:\buildkite-agent\elastic-stack-bootstrap-status $case.Marker }
        $global:LASTEXITCODE=0
        & $program | Out-Null
        $exitCode=$LASTEXITCODE
        if (($exitCode -ne 0) -ne [bool]$case.Fails) { throw "Unexpected exit $exitCode for $($case.Name)" }
        if ($case.ContainsKey('MaxSleep') -and $testState.slept -gt $case.MaxSleep) { throw "Permanent failure retried for $($testState.slept) seconds: $($case.Name)" }
        if ($case.Expired -and $testState.continues) { throw 'Expired launch attempted CONTINUE' }
        if ($testState.abandoned -ne [bool]$case.Abandon -or $testState.unhealthy -ne [bool]$case.Unhealthy) { throw "Wrong instance recovery: $($case.Name)" }
        if ($case.Skip -and ($testState.configured -ne 0 -or (Get-Content C:\buildkite-agent\buildkite-agent.cfg -Raw).Trim() -ne 'original configuration')) { throw "Configuration changed: $($case.Name)" }
        if ($case.MarkerWriteFails -and (-not $testState.agentStarted -or $testState.continues -ne 0 -or (Get-Content C:\buildkite-agent\elastic-stack-bootstrap-status -Raw).Trim() -ne 'Started')) { throw 'Marker write failure did not preserve the started agent and incomplete status' }
        if (-not $case.Fails) {
            if ((Get-Content C:\buildkite-agent\elastic-stack-bootstrap-status -Raw).Trim() -ne 'Completed') { throw "Configuration not completed: $($case.Name)" }
            if ($testState.signaled -eq [bool]$case.NoSignal) { throw "Wrong CloudFormation outcome: $($case.Name)" }
        } elseif ($testState.signaled) { throw "Failed bootstrap signaled success: $($case.Name)" }
        Write-Host "PASS: $($case.Name)"
    }

    # Execute the template's userdata wrapper with a real child PowerShell process.
    # Service/AWS mocks alone cannot catch lost native stderr or log encoding errors.
    $template = Get-Content (Join-Path $PSScriptRoot '../../templates/aws-stack.yml') -Raw
    $wrapper = [regex]::Match($template, '(?s)<powershell>(.*?)</powershell>').Groups[1].Value
    $wrapper = $wrapper -replace '\$\{[^}]+\}', 'fixture'
    $fixture = Join-Path $scratch 'logging-child.ps1'
    $log = Join-Path $scratch 'bootstrap.log'
    Set-Content -Path $fixture -Encoding utf8 -Value @'
Write-Output ('bootstrap stdout caf' + [char]0xE9)
Write-Warning 'bootstrap warning'
[Console]::Error.WriteLine('bootstrap stderr')
exit 7
'@
    $wrapper = $wrapper.Replace('powershell -file C:\buildkite-agent\bin\bk-install-elastic-stack.ps1', "& '$((Get-Process -Id $PID).Path)' -NoProfile -File '$fixture'")
    $wrapper = $wrapper.Replace('C:\buildkite-agent\elastic-stack.log', "'$log'")
    $wrapperFile = Join-Path $scratch 'userdata.ps1'
    Set-Content -Path $wrapperFile -Value $wrapper
    & $wrapperFile
    if ($LASTEXITCODE -ne 7) { throw 'Userdata did not preserve the bootstrap exit code' }
    $logged = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($log))
    foreach ($message in @(('bootstrap stdout caf' + [char]0xE9), 'bootstrap warning', 'bootstrap stderr')) {
        if (-not $logged.Contains($message)) { throw "Missing UTF-8 bootstrap log message: $message" }
    }
    Write-Host 'PASS: userdata preserves bootstrap stdout, warnings, stderr, UTF-8, and exit code'
} finally {
    Remove-PSDrive C
    Remove-Item $scratch -Recurse -Force
}
Write-Host "All $($cases.Count) bootstrap scenarios passed. Windows/ASG integration validation remains required."
