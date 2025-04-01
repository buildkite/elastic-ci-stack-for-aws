## Installs the Buildkite Agent, run from the CloudFormation template

Set-PSDebug -Trace 2

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

function on_error {
  $errorLine=$_.InvocationInfo.ScriptLineNumber
  $errorMessage=$_.Exception

  $Token = (Invoke-WebRequest -UseBasicParsing -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content
  $instance_id=(Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content

  aws autoscaling set-instance-health `
    --instance-id "$instance_id" `
    --health-status Unhealthy

  cfn-signal `
    --region "$Env:AWS_REGION" `
    --stack "$Env:BUILDKITE_STACK_NAME" `
    --reason "Error on line ${errorLine}: $errorMessage" `
    --resource "AgentAutoScaleGroup" `
    --exit-code 1
}

trap {on_error}

$Token = (Invoke-WebRequest -UseBasicParsing -Method Put -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '60'} http://169.254.169.254/latest/api/token).content
$Env:INSTANCE_ID=(Invoke-WebRequest -UseBasicParsing -Headers @{'X-aws-ec2-metadata-token' = $Token} http://169.254.169.254/latest/meta-data/instance-id).content
$DOCKER_VERSION=(docker --version).split(" ")[2].Replace(",","")

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

set_always         "BUILDKITE_ECR_POLICY" "$Env:BUILDKITE_ECR_POLICY"
set_always         "BUILDKITE_SECRETS_BUCKET" "$Env:BUILDKITE_SECRETS_BUCKET"
set_always         "BUILDKITE_SECRETS_BUCKET_REGION" "$Env:BUILDKITE_SECRETS_BUCKET_REGION"
set_always         "BUILDKITE_STACK_NAME" "$Env:BUILDKITE_STACK_NAME"
set_always         "BUILDKITE_STACK_VERSION" "$Env:BUILDKITE_STACK_VERSION"
set_always         "BUILDKITE_DOCKER_EXPERIMENTAL" "$DOCKER_EXPERIMENTAL"
set_always         "DOCKER_VERSION" "$DOCKER_VERSION"
set_always         "PLUGINS_ENABLED" "$PLUGINS_ENABLED"
set_unless_present "AWS_DEFAULT_REGION" "$Env:AWS_REGION"
set_unless_present "AWS_REGION" "$Env:AWS_REGION"
set_unless_present "BUILDKITE_AGENT_ENDPOINT" "https://agent.buildkite.com/v3"
"@

If ($Env:BUILDKITE_AGENT_RELEASE -eq "edge") {
  Write-Output "Downloading buildkite-agent edge..."
  Invoke-WebRequest -OutFile C:\buildkite-agent\bin\buildkite-agent-edge.exe -Uri "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-windows-amd64.exe"
  buildkite-agent-edge.exe --version
  If ($lastexitcode -ne 0) { Exit $lastexitcode }
}

# Check if the source agent executable exists before copying
$sourceAgentPath = "C:\buildkite-agent\bin\buildkite-agent-${Env:BUILDKITE_AGENT_RELEASE}.exe"
if (-not (Test-Path -Path $sourceAgentPath -PathType Leaf)) {
  Write-Error "Source agent executable not found: $sourceAgentPath. Check AMI build logs or agent release parameter."
  # The trap should handle signaling failure, but we explicitly exit just in case.
  exit 1
}
Copy-Item -Path $sourceAgentPath -Destination C:\buildkite-agent\bin\buildkite-agent.exe

$agent_metadata=@(
  "queue=${Env:BUILDKITE_QUEUE}"
  "docker=${DOCKER_VERSION}"
  "stack=${Env:BUILDKITE_STACK_NAME}"
  "buildkite-aws-stack=${Env:BUILDKITE_STACK_VERSION}"
)

If (Test-Path Env:BUILDKITE_AGENT_TAGS) {
  $agent_metadata += $Env:BUILDKITE_AGENT_TAGS.split(",")
}

# Enable git-mirrors
If ($Env:BUILDKITE_AGENT_ENABLE_GIT_MIRRORS -eq "true") {
  $Env:BUILDKITE_AGENT_GIT_MIRRORS_PATH = "C:\buildkite-agent\git-mirrors"
}

# Either you can have timestamp-lines xor ansi-timestamps.
# There's no technical reason you can't have both, its a pragmatic decision to
# simplify the avaliable parameters on the stack
If ($Env:BUILDKITE_AGENT_TIMESTAMP_LINES -eq "true") {
  $Env:BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS = "true"
} Else {
  $Env:BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS = "false"
}

# Get token from ssm param (if we have a path)
If ($null -ne $Env:BUILDKITE_AGENT_TOKEN_PATH -and $Env:BUILDKITE_AGENT_TOKEN_PATH -ne "") {
  $Env:BUILDKITE_AGENT_TOKEN = $(aws ssm get-parameter --name $Env:BUILDKITE_AGENT_TOKEN_PATH --with-decryption --output text --query Parameter.Value --region $Env:AWS_REGION)
}

$OFS=","
Set-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value @"
name="${Env:BUILDKITE_STACK_NAME}-${Env:INSTANCE_ID}-%spawn"
token="${Env:BUILDKITE_AGENT_TOKEN}"
endpoint="${Env:BUILDKITE_AGENT_ENDPOINT}"
tags=$agent_metadata
tags-from-ec2-meta-data=true
no-ansi-timestamps=${Env:BUILDKITE_AGENT_NO_ANSI_TIMESTAMPS}
timestamp-lines=${Env:BUILDKITE_AGENT_TIMESTAMP_LINES}
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
tracing-backend=${Env:BUILDKITE_AGENT_TRACING_BACKEND}
signing-aws-kms-key=${Env:BUILDKITE_AGENT_SIGNING_KMS_KEY}
verification-failure-behavior=${Env:BUILDKITE_AGENT_SIGNING_FAILURE_BEHAVIOR}
"@
$OFS=" "

nssm set lifecycled AppEnvironmentExtra +AWS_REGION=$Env:AWS_REGION
nssm set lifecycled AppEnvironmentExtra +LIFECYCLED_HANDLER="C:\buildkite-agent\bin\stop-agent-gracefully.ps1"
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
  # Consider explicitly calling the error handler or ensuring exit code triggers trap
  exit 1 # Ensure script exits on failure
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

If (![string]::IsNullOrEmpty($Env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT)) {
  Write-Output "Running the elastic bootstrap script"
  C:\buildkite-agent\bin\bk-fetch.ps1 -From "$Env:BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT" -To C:\buildkite-agent\elastic_bootstrap.ps1
  C:\buildkite-agent\elastic_bootstrap.ps1
  Remove-Item -Path C:\buildkite-agent\elastic_bootstrap.ps1
}

If (![string]::IsNullOrEmpty($Env:BUILDKITE_ENV_FILE_URL)) {
  C:\buildkite-agent\bin\bk-fetch.ps1 -From "$Env:BUILDKITE_ENV_FILE_URL" -To C:\buildkite-agent\env
}

Write-Output "Starting the Buildkite Agent"

nssm install buildkite-agent C:\buildkite-agent\bin\buildkite-agent.exe start
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent ObjectName .\$UserName $Password
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppStdout C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppStderr C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppEnvironmentExtra +HOME=C:\buildkite-agent

If ((![string]::IsNullOrEmpty($Env:BUILDKITE_ENV_FILE_URL)) -And (Test-Path -Path C:\buildkite-agent\env -PathType leaf)) {
  foreach ($var in Get-Content C:\buildkite-agent\env) {
    nssm set buildkite-agent AppEnvironmentExtra "+$var"
    If ($lastexitcode -ne 0) { Exit $lastexitcode }
  }
}

# also set in cfn so it's show in job logs
nssm set buildkite-agent AppEnvironmentExtra +BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB=$Env:BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppExit Default Restart
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppRestartDelay 10000
If ($lastexitcode -ne 0) { Exit $lastexitcode }

nssm set buildkite-agent AppEvents Exit/Post "powershell C:\buildkite-agent\bin\terminate-instance.ps1"
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Restart-Service buildkite-agent

# renable debug tracing
Set-PSDebug -Trace 2

# let the stack know that this host has been initialized successfully
cfn-signal `
  --region "$Env:AWS_REGION" `
  --stack "$Env:BUILDKITE_STACK_NAME" `
  --resource "AgentAutoScaleGroup" `
  --exit-code 0 ; if (-not $?) {
    # This will fail if the stack has already completed, for instance if there is a min size
    # of 1 and this is the 2nd instance. This is ok, so we just ignore the erro
    Write-Output "Signal failed"
  }

Set-PSDebug -Off
