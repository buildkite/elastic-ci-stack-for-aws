## Installs the Buildkite Agent, run from the CloudFormation template

Set-PSDebug -Trace 2

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$StatusFile = 'C:\buildkite-agent\elastic-stack-bootstrap-status'
$BootstrapCompleted = $false
$AgentStarted = $false
$InstanceIdentity = $null
$LaunchDeadline = $null

function Initialize-InstanceIdentity {
  if ($script:InstanceIdentity) { return }
  $Token = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).Content
  $Identity = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/dynamic/instance-identity/document).Content | ConvertFrom-Json
  $Env:INSTANCE_ID = $Identity.instanceId
  # pendingTime precedes the launch hook: use a conservative deadline that includes
  # Windows setup, not a fresh timeout starting when this script runs.
  $script:LaunchDeadline = ([DateTimeOffset]::Parse($Identity.pendingTime)).AddSeconds([int]$Env:BUILDKITE_LAUNCH_TIMEOUT)
  $script:InstanceIdentity = $Identity
}

function Invoke-AutoScaling {
  param([string[]]$Arguments)
  # Retry at the lifecycle boundary, not inside the CLI. Bound each request so a
  # network outage cannot prevent the launch deadline from taking effect.
  $PreviousAttempts = $Env:AWS_MAX_ATTEMPTS
  $Env:AWS_MAX_ATTEMPTS = '1'
  try {
    $ErrorActionPreference = 'Continue' # Capture native stderr in Windows PowerShell 5.1.
    $Output = aws autoscaling @Arguments --region "$Env:AWS_REGION" --output json --no-cli-pager --cli-connect-timeout 2 --cli-read-timeout 3 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Auto Scaling $($Arguments[0]) failed: $Output" }
    return ($Output -join "`n")
  } finally {
    $Env:AWS_MAX_ATTEMPTS = $PreviousAttempts
  }
}

function Complete-InstanceLaunch {
  param([ValidateSet('CONTINUE', 'ABANDON')][string]$Result, [DateTimeOffset]$Deadline)
  $Backoff = 1
  $RetryAllowed = $true
  do {
    $ActionAttempted = $false
    try {
      $Instance = (Invoke-AutoScaling -Arguments @('describe-auto-scaling-instances', '--instance-ids', $Env:INSTANCE_ID) | ConvertFrom-Json).AutoScalingInstances | Select-Object -First 1
      if (-not $Instance -or $Instance.LifecycleState -like 'Terminating*') {
        Write-Warning 'Instance is absent or terminating; no launch action to complete.'
        return $false
      }
      if ($Instance.LifecycleState -eq 'InService') {
        if ($Result -eq 'ABANDON') {
          if (-not $RetryAllowed) { return $false }
          $ActionAttempted = $true
          Invoke-AutoScaling -Arguments @('set-instance-health', '--instance-id', $Env:INSTANCE_ID, '--health-status', 'Unhealthy') | Out-Null
        }
        return $true
      }
      # Reconcile an unsuccessful completion call before deciding whether to retry.
      # A missing lifecycle action alone is not confirmation of a successful launch.
      if (([DateTimeOffset](Get-Date)) -ge $Deadline.AddSeconds(-10)) { return $false }
      if ($Instance.LifecycleState -eq 'Pending:Wait') {
        if (-not $RetryAllowed) { return $false }
        $ActionAttempted = $true
        Invoke-AutoScaling -Arguments @('complete-lifecycle-action', '--instance-id', $Env:INSTANCE_ID,
          '--auto-scaling-group-name', $Instance.AutoScalingGroupName,
          '--lifecycle-hook-name', $Env:BUILDKITE_LAUNCH_HOOK_NAME, '--lifecycle-action-result', $Result) | Out-Null
        return $true
      }
    } catch {
      Write-Warning $_
      $RetryAllowed = $_.Exception.Message -match 'Throttl|ResourceContention|ScalingActivityInProgress|RequestTimeout|ServiceUnavailable|InternalError|timed? ?out|connect|endpoint|connection'
      if (-not $RetryAllowed -and -not $ActionAttempted) { return $false }
    }
    if (([DateTimeOffset](Get-Date)).AddSeconds($Backoff + 10) -ge $Deadline) { return $false }
    Start-Sleep -Seconds $Backoff
    $Backoff = [Math]::Min($Backoff * 2, 15)
  } while ($true)
}

function Complete-StackBootstrap {
  # Configuration is already complete. Neither callback may invoke the bootstrap
  # failure handler or stop an agent that could now be processing a job.
  try {
    Initialize-InstanceIdentity
    if (-not (Complete-InstanceLaunch -Result CONTINUE -Deadline $script:LaunchDeadline)) {
      Write-Warning 'Launch completion unconfirmed; leaving recovery to the launch hook timeout.'
      return
    }
    if ($Env:BUILDKITE_STACK_DEPLOYED_BY -eq 'cloudformation') {
      cfn-signal --region "$Env:AWS_REGION" --stack "$Env:BUILDKITE_STACK_NAME" --resource AgentAutoScaleGroup --exit-code 0
      if ($LASTEXITCODE -ne 0) { Write-Warning 'CloudFormation success signal failed.' }
    }
  } catch {
    Write-Warning "Configuration completed, but AWS acknowledgment failed: $_"
  }
}

trap {
  Write-Warning "Bootstrap failed at line $($_.InvocationInfo.ScriptLineNumber): $_"
  if (-not $BootstrapCompleted -and -not $AgentStarted) {
    try {
      # Allow file collection and the default 5s CloudWatch flush interval before
      # ABANDON can terminate this instance. This is best-effort, not delivery confirmation.
      Start-Sleep -Seconds 10
      Initialize-InstanceIdentity
      if (-not (Complete-InstanceLaunch -Result ABANDON -Deadline (Get-Date).AddSeconds(30))) {
        Write-Warning 'Bootstrap recovery unconfirmed; a pending launch will time out.'
      }
    } catch {
      Write-Warning "Could not report bootstrap failure: $_"
    }
  }
  # Do not fail CloudFormation on one bad launch: allow a replacement to succeed
  # within the creation timeout. Always retain the original failure in the log.
  exit 1
}

if (Test-Path $StatusFile) {
  $Status = (Get-Content -Raw $StatusFile).Trim()
  if ($Status -ne 'Completed') { throw "Previous bootstrap did not complete (status: $Status)." }
  $BootstrapCompleted = $true
  Complete-StackBootstrap
  exit 0
}
Set-Content -Path $StatusFile -Value Started
icacls $StatusFile /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F'
if ($LASTEXITCODE -ne 0) { throw 'Could not protect the bootstrap status file.' }

Initialize-InstanceIdentity
powershell -NoProfile -File C:\buildkite-agent\bin\bk-configure-docker.ps1
if ($LASTEXITCODE -ne 0) { throw 'Docker configuration failed.' }
$DOCKER_VERSION=(docker --version).split(" ")[2].Replace(",","")
if ($LASTEXITCODE -ne 0) { throw 'Could not determine the Docker version.' }

$PLUGINS_ENABLED=@()
If ($Env:SECRETS_PLUGIN_ENABLED -eq "true") { $PLUGINS_ENABLED += "secrets" }
If ($Env:ECR_PLUGIN_ENABLED -eq "true") { $PLUGINS_ENABLED += "ecr" }
If ($Env:DOCKER_LOGIN_PLUGIN_ENABLED -eq "true") { $PLUGINS_ENABLED += "docker-login" }

# cfn-env is sourced by the environment hook in builds

# There's a confusing situation here, because this is PowerShell, writing out a script which will be
# evaluated in Bash.  So take note of the mixed export / $Env:.. idioms.  This code mirrors the same
# behaviour of the script in /packer/linux/conf/bin/bk-install-elastic-stack.sh.

Set-Content -Path C:\buildkite-agent\cfn-env -Value @'
# The Buildkite agent sets a number of variables such as AWS_DEFAULT_REGION to fixed values which
# are determined at AMI-build-time.  However, sometimes a user might want to override such variables
# using an env: block in their pipeline.yml.  This little helper is sets the environment variables
# buildkite-agent and plugins expect, except if a user want to override them, for example to do a
# deployment to a region other than where the Buildkite agent lives.
function set_unless_present() {
    local target=$1
    local value=$2

    if [[ -v "${target}" ]]; then
        echo "^^^ +++"
        echo "⚠️ ${target} already set, NOT overriding! (current value \"${!target}\" set by Buildkite step env configuration, or inherited from the buildkite-agent process environment)"
    else
        echo "export ${target}=\"${value}\""
        declare -gx "${target}=${value}"
    fi
}

function set_always() {
    local target=$1
    local value=$2

    echo "export ${target}=\"${value}\""
    declare -gx "${target}=${value}"
}
'@

Add-Content -Path C:\buildkite-agent\cfn-env -Value @"

set_always         "BUILDKITE_AGENTS_PER_INSTANCE" "$Env:BUILDKITE_AGENTS_PER_INSTANCE"

# also set via nssm
set_always         "BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB" "$Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB"
set_always         "BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL" "$Env:BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL"
set_always         "BUILDKITE_PURGE_BUILDS_ON_DISK_FULL" "$Env:BUILDKITE_PURGE_BUILDS_ON_DISK_FULL"

set_always         "BUILDKITE_ECR_POLICY" "$Env:BUILDKITE_ECR_POLICY"
set_always         "ECR_CREDENTIAL_HELPER_ENABLED" "$Env:ECR_CREDENTIAL_HELPER_ENABLED"
set_always         "BUILDKITE_SECRETS_BUCKET" "$Env:BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_SECRETS_BUCKET_REGION" "$Env:BUILDKITE_SECRETS_BUCKET_REGION"
set_always         "BUILDKITE_STACK_NAME" "$Env:BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$Env:BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_VERSION" "$DOCKER_VERSION"
set_always         "PLUGINS_ENABLED" "$PLUGINS_ENABLED"
set_always         "BUILDKITE_ARTIFACTS_BUCKET" "$Env:BUILDKITE_ARTIFACTS_BUCKET"
set_always         "BUILDKITE_S3_DEFAULT_REGION" "$Env:BUILDKITE_S3_DEFAULT_REGION"
set_always         "BUILDKITE_S3_ACL" "$Env:BUILDKITE_S3_ACL"
set_unless_present "AWS_DEFAULT_REGION" "$Env:AWS_REGION"
set_unless_present "AWS_REGION" "$Env:AWS_REGION"
set_unless_present "BUILDKITE_AGENT_ENDPOINT" "https://agent-edge.buildkite.com/v3"
"@

If ($Env:BUILDKITE_AGENT_RELEASE -eq "edge") {
  Write-Output "Downloading buildkite-agent edge..."
  Invoke-WebRequest -OutFile C:\buildkite-agent\bin\buildkite-agent-edge.exe -Uri "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-windows-amd64.exe"
  buildkite-agent-edge.exe --version
  If ($lastexitcode -ne 0) { throw "Agent version check failed ($lastexitcode)." }
}

# Check if the source agent executable exists before copying
$sourceAgentPath = "C:\buildkite-agent\bin\buildkite-agent-${Env:BUILDKITE_AGENT_RELEASE}.exe"
if (-not (Test-Path -Path $sourceAgentPath -PathType Leaf)) {
  throw "Source agent executable not found: $sourceAgentPath. Check AMI build logs or agent release parameter."
}
Copy-Item -Path $sourceAgentPath -Destination C:\buildkite-agent\bin\buildkite-agent.exe

$agent_metadata=@(
  "queue=${Env:BUILDKITE_QUEUE}"
  "docker=${DOCKER_VERSION}"
  "stack=${Env:BUILDKITE_STACK_NAME}"
  "buildkite-aws-stack=${Env:BUILDKITE_STACK_VERSION}"
  "stack-deployed-by=${Env:BUILDKITE_STACK_DEPLOYED_BY}"
)

If (Test-Path Env:BUILDKITE_AGENT_TAGS) {
  $agent_metadata += $Env:BUILDKITE_AGENT_TAGS.split(",")
}

# Enable git-mirrors
If ($Env:BUILDKITE_AGENT_ENABLE_GIT_MIRRORS -eq "true") {
  $Env:BUILDKITE_AGENT_GIT_MIRRORS_PATH = "C:\buildkite-agent\git-mirrors"
}

# Get token from ssm param (if we have a path)
If ($null -ne $Env:BUILDKITE_AGENT_TOKEN_PATH -and $Env:BUILDKITE_AGENT_TOKEN_PATH -ne "") {
  $Env:BUILDKITE_AGENT_TOKEN = $(aws ssm get-parameter --name $Env:BUILDKITE_AGENT_TOKEN_PATH --with-decryption --output text --query Parameter.Value --region $Env:AWS_REGION)
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the agent token.' }
}

If ([string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_OPENTELEMETRY_TRACING)) {
  $Env:BUILDKITE_AGENT_OPENTELEMETRY_TRACING = "false"
}
If ([string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_CANCEL_SIGNAL_TIMEOUT)) {
  $Env:BUILDKITE_AGENT_CANCEL_SIGNAL_TIMEOUT = "10s"
}
If ([string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_CANCEL_CLEANUP_TIMEOUT)) {
  $Env:BUILDKITE_AGENT_CANCEL_CLEANUP_TIMEOUT = "5s"
}

$OFS=","
Set-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value @"
name="${Env:BUILDKITE_STACK_NAME}-${Env:INSTANCE_ID}-%spawn"
token="${Env:BUILDKITE_AGENT_TOKEN}"
endpoint="${Env:BUILDKITE_AGENT_ENDPOINT}"
tags=$agent_metadata
tags-from-ec2-meta-data=true
hooks-path="C:\buildkite-agent\hooks"
build-path="C:\buildkite-agent\builds"
plugins-path="C:\buildkite-agent\plugins"
git-mirrors-path="${Env:BUILDKITE_AGENT_GIT_MIRRORS_PATH}"
experiment="${Env:BUILDKITE_AGENT_EXPERIMENTS}"
priority=%n
spawn=${Env:BUILDKITE_AGENTS_PER_INSTANCE}
no-color=true
shell=powershell
disconnect-after-idle-timeout=${Env:BUILDKITE_SCALE_IN_IDLE_PERIOD}
disconnect-after-job=${Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB}
disconnect-after-uptime=${Env:BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME}
opentelemetry-tracing=${Env:BUILDKITE_AGENT_OPENTELEMETRY_TRACING}
cancel-signal-timeout=${Env:BUILDKITE_AGENT_CANCEL_SIGNAL_TIMEOUT}
cancel-cleanup-timeout=${Env:BUILDKITE_AGENT_CANCEL_CLEANUP_TIMEOUT}
signing-aws-kms-key=${Env:BUILDKITE_AGENT_SIGNING_KMS_KEY}
verification-failure-behavior=${Env:BUILDKITE_AGENT_JOB_VERIFICATION_NO_SIGNATURE_BEHAVIOR}
"@
$OFS=" "

If (![string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_SIGNING_KEY_PATH)) {
  Write-Output "Fetching signing key from ssm: $Env:BUILDKITE_AGENT_SIGNING_KEY_PATH..."

  $keyfile="C:\buildkite-agent\signing-key.json"

  # Write as UTF-8 no-BOM; `> $keyfile` would use Out-File's PS 5.1 default
  # (UTF-16LE+BOM) which the agent's Go JSON parser rejects.
  $signingJwks = aws ssm get-parameter `
    --name "$Env:BUILDKITE_AGENT_SIGNING_KEY_PATH" `
    --with-decryption `
    --query Parameter.Value `
    --output text
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the signing key.' }
  [System.IO.File]::WriteAllText($keyfile, $signingJwks, (New-Object System.Text.UTF8Encoding $false))

  Add-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value "signing-jwks-file=$keyfile"
}

if (![string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_SIGNING_KEY_ID)) {
  Add-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value "signing-jwks-key-id=$Env:BUILDKITE_AGENT_SIGNING_KEY_ID"
}

if (![string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_VERIFICATION_KEY_PATH)) {
  Write-Output "Fetching verification key from ssm: $Env:BUILDKITE_AGENT_VERIFICATION_KEY_PATH..."

  $keyfile="C:\buildkite-agent\verification-key.json"

  # Write as UTF-8 no-BOM; see note in signing-key block above.
  $verificationJwks = aws ssm get-parameter `
    --name "$Env:BUILDKITE_AGENT_VERIFICATION_KEY_PATH" `
    --with-decryption `
    --query Parameter.Value `
    --output text
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the verification key.' }
  [System.IO.File]::WriteAllText($keyfile, $verificationJwks, (New-Object System.Text.UTF8Encoding $false))

  Add-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value "verification-jwks-file=$keyfile"
}

nssm set lifecycled AppEnvironmentExtra +AWS_REGION=$Env:AWS_REGION
if ($LASTEXITCODE -ne 0) { throw 'Could not configure lifecycled region.' }
nssm set lifecycled AppEnvironmentExtra +LIFECYCLED_HANDLER="C:\buildkite-agent\bin\stop-agent-gracefully.ps1"
if ($LASTEXITCODE -ne 0) { throw 'Could not configure lifecycled handler.' }
Restart-Service lifecycled

# wait for docker service and API to be ready
$next_wait_time=0
$max_wait_time=30 # Increased wait time
$docker_ready = $false
do {
  Write-Output "Waiting for Docker... ($next_wait_time/$max_wait_time seconds)"
  Start-Sleep -Seconds 1 # Sleep 1 second each iteration
  $next_wait_time++

  # Check Docker service status
  $dockerService = Get-Service docker -ErrorAction SilentlyContinue
  if ($dockerService -ne $null -and $dockerService.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
    Write-Output "Docker service is running. Checking API..."
    # Try docker ps, capture errors, check success status
    try {
        # Run docker ps, redirect stdout to null, keep stderr for potential capture
        docker ps *> $null
        # If the command succeeded ($? is true)
        if ($?) {
            Write-Output "Docker API is responsive."
            $docker_ready = $true
        } else {
            # Command failed without throwing terminating exception, $? is false
            Write-Warning "Docker service running, but API not responsive yet (docker ps failed)."
            # Try to capture the error output directly for more context
            $ErrorActionPreference = "SilentlyContinue" # Prevent non-terminating errors below from stopping script
            $dockerErrorOutput = docker ps 2>&1 | Out-String
            $ErrorActionPreference = "Stop" # Restore error preference
            if ($dockerErrorOutput) {
                Write-Warning "Docker ps error output: $dockerErrorOutput"
            }
        }
    } catch {
        # Command failed with a terminating exception
        Write-Warning "Docker service running, but API not responsive yet (docker ps threw an exception)."
        Write-Warning "Docker ps exception details: $($_.Exception.Message)"
        # Optionally log the full error record: Write-Warning $_
    }
  } else {
    Write-Output "Docker service is not running or not found."
  }

} until ($docker_ready -OR ($next_wait_time -ge $max_wait_time))

# Final check after the loop
if ($docker_ready) {
  Write-Output "Docker is ready."
  # Optionally run docker ps again to show output if needed, but the check already passed
  # docker ps
} else {
  Write-Output "Failed to confirm Docker readiness after $max_wait_time seconds."
  # Add more diagnostics if possible
  $dockerService = Get-Service docker -ErrorAction SilentlyContinue
  Write-Output "Final Docker Service Status: $($dockerService.Status)"
  throw 'Docker did not become ready.'
}

# prevent password from being revealed by debug tracing
Set-PSDebug -Trace 0

Write-Output "Creating buildkite-agent user account in Administrators group"

$lowerChars = [char[]](97..122)  # a-z
$upperChars = [char[]](65..90)   # A-Z
$numbers = [char[]](48..57)      # 0-9
$specialChars = [char[]](40, 41, 33, 64, 36, 37, 45, 61, 46, 63, 42, 59, 38)  # ()!@$%-=.?*;&

$minPasswordLength = 32
$randomChars = @()

Do {
  $randomChars += Get-Random -Count 1 -InputObject $lowerChars
  $randomChars += Get-Random -Count 1 -InputObject $upperChars
  $randomChars += Get-Random -Count 1 -InputObject $numbers
  $randomChars += Get-Random -Count 1 -InputObject $specialChars

  # randomize the order of the random characters
  $randomChars = Get-Random -Count $randomChars.Length -InputObject $randomChars
} While ($randomChars.Length -lt $minPasswordLength)

$Password = -join $randomChars

$UserName = "buildkite-agent"

New-LocalUser -Name $UserName -PasswordNeverExpires -Password ($Password | ConvertTo-SecureString -AsPlainText -Force) | out-null

If ($Env:BUILDKITE_WINDOWS_ADMINISTRATOR -eq "true") {
  Add-LocalGroupMember -Group "Administrators" -Member $UserName | out-null
}

# terminate-instance.ps1 runs as this user and shuts the instance down as a last
# resort. Non-administrators can't shut down Windows Server by default, so grant
# the right explicitly. The instance role can already terminate this instance.
. C:\buildkite-agent\bin\bk-user-rights.ps1
[BkUserRights]::Add((Get-LocalUser -Name $UserName).SID.Value, "SeShutdownPrivilege")

# Set JWKS key file permissions now that the buildkite-agent user exists
If (![string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_SIGNING_KEY_PATH)) {
  $keyfile = "C:\buildkite-agent\signing-key.json"
  Write-Output "Setting permissions for $keyfile..."
  icacls "$keyfile" /inheritance:r /grant:r "Administrators:F" /grant:r "${UserName}:R"
  if ($LASTEXITCODE -ne 0) { throw 'Could not protect the signing key.' }
}
If (![string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_VERIFICATION_KEY_PATH)) {
  $keyfile = "C:\buildkite-agent\verification-key.json"
  Write-Output "Setting permissions for $keyfile..."
  icacls "$keyfile" /inheritance:r /grant:r "Administrators:F" /grant:r "${UserName}:R"
  if ($LASTEXITCODE -ne 0) { throw 'Could not protect the verification key.' }
}

If (![string]::IsNullOrEmpty($Env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT)) {
  Write-Output "Running the elastic bootstrap script"
  $global:LASTEXITCODE = 0
  C:\buildkite-agent\bin\bk-fetch.ps1 -From "$Env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" -To C:\buildkite-agent\elastic_bootstrap.ps1
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the elastic bootstrap script.' }
  C:\buildkite-agent\elastic_bootstrap.ps1
  if ($LASTEXITCODE -ne 0) { throw "Elastic bootstrap script failed ($LASTEXITCODE)." }
  Remove-Item -Path C:\buildkite-agent\elastic_bootstrap.ps1
}

If (![string]::IsNullOrEmpty($Env:BUILDKITE_ENV_FILE_URL)) {
  $global:LASTEXITCODE = 0
  C:\buildkite-agent\bin\bk-fetch.ps1 -From "$Env:BUILDKITE_ENV_FILE_URL" -To C:\buildkite-agent\env
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the agent environment file.' }
}

Write-Output "Configuring the Buildkite Agent service"

nssm install buildkite-agent C:\buildkite-agent\bin\buildkite-agent.exe start
If ($lastexitcode -ne 0) { throw "Agent service installation failed ($lastexitcode)." }

nssm set buildkite-agent ObjectName .\$UserName $Password
If ($lastexitcode -ne 0) { throw "Agent service account configuration failed ($lastexitcode)." }

nssm set buildkite-agent AppStdout C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { throw "Agent stdout configuration failed ($lastexitcode)." }

nssm set buildkite-agent AppStderr C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { throw "Agent stderr configuration failed ($lastexitcode)." }

nssm set buildkite-agent AppEnvironmentExtra +HOME=C:\buildkite-agent
if ($LASTEXITCODE -ne 0) { throw 'Agent HOME configuration failed.' }

If ((![string]::IsNullOrEmpty($Env:BUILDKITE_ENV_FILE_URL)) -And (Test-Path -Path C:\buildkite-agent\env -PathType leaf)) {
  foreach ($var in Get-Content C:\buildkite-agent\env) {
    nssm set buildkite-agent AppEnvironmentExtra "+$var"
    If ($lastexitcode -ne 0) { throw "Agent environment configuration failed ($lastexitcode)." }
  }
}

# also set in cfn so it's show in job logs
nssm set buildkite-agent AppEnvironmentExtra +BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=$Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB
If ($lastexitcode -ne 0) { throw "Agent termination configuration failed ($lastexitcode)." }

# Don't restart the agent when it exits. NSSM runs the Exit/Post hook
# asynchronously, so a restart can't wait for terminate-instance.ps1 and the
# agent would accept jobs on an instance that is terminating (#753).
nssm set buildkite-agent AppExit Default Exit
If ($lastexitcode -ne 0) { throw "Agent exit policy configuration failed ($lastexitcode)." }

nssm set buildkite-agent AppEvents Exit/Post "powershell C:\buildkite-agent\bin\terminate-instance.ps1"
If ($lastexitcode -ne 0) { throw "Agent exit hook configuration failed ($lastexitcode)." }

Write-Output "Configuring CloudWatch agent log retention..."
if ($Env:EC2_LOG_RETENTION_DAYS -and $Env:ENABLE_EC2_LOG_RETENTION_POLICY -eq "true") {
  Write-Output "Setting CloudWatch EC2 log retention to $($Env:EC2_LOG_RETENTION_DAYS) days"
  Write-Output "WARNING: This will delete EC2 logs older than $($Env:EC2_LOG_RETENTION_DAYS) days from existing log groups"

  $configFile = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json"
  if (Test-Path $configFile) {
    # Add retention_in_days to all collect_list items using jq
    $tempFile = "$env:TEMP\cloudwatch_config.json"
    & jq --arg retention $Env:EC2_LOG_RETENTION_DAYS '
      .logs.logs_collected.files.collect_list |= map(. + {"retention_in_days": ($retention | tonumber)}) |
      .logs.logs_collected.windows_events.collect_list |= map(. + {"retention_in_days": ($retention | tonumber)})
    ' $configFile > $tempFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not update CloudWatch log retention configuration.' }
    Move-Item $tempFile $configFile

    # Restart CloudWatch agent to pick up the new configuration
    try {
      & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -s -c "file:$configFile"
      Write-Output "CloudWatch agent configuration updated and restarted"
    } catch {
      Write-Output "Warning: Failed to restart CloudWatch agent: $($_.Exception.Message)"
    }
  } else {
    Write-Output "Warning: CloudWatch agent config file not found at $configFile"
  }
} elseif ($Env:EC2_LOG_RETENTION_DAYS) {
  Write-Output "EC2 log retention set to $($Env:EC2_LOG_RETENTION_DAYS) days but EnableEC2LogRetentionPolicy is false"
  Write-Output "Skipping EC2 log retention configuration to protect existing logs"
} else {
  Write-Output "EC2 log retention not set, using CloudWatch agent defaults (never expire)"
}

# renable debug tracing
Set-PSDebug -Trace 2

Start-Service AmazonCloudWatchAgent
Write-Output "Starting the Buildkite Agent"
Start-Service buildkite-agent
$AgentStarted = $true
Set-Content -Path $StatusFile -Value Completed
$BootstrapCompleted = $true
Complete-StackBootstrap

Set-PSDebug -Off
exit 0
