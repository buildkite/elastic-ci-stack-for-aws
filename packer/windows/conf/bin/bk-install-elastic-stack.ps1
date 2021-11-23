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
"@

If ($Env:BUILDKITE_AGENT_RELEASE -eq "edge") {
  Write-Output "Downloading buildkite-agent edge..."
  Invoke-WebRequest -OutFile C:\buildkite-agent\bin\buildkite-agent-edge.exe -Uri "https://download.buildkite.com/agent/experimental/latest/buildkite-agent-windows-amd64.exe"
  buildkite-agent-edge.exe --version
  If ($lastexitcode -ne 0) { Exit $lastexitcode }
}

Copy-Item -Path C:\buildkite-agent\bin\buildkite-agent-${Env:BUILDKITE_AGENT_RELEASE}.exe -Destination C:\buildkite-agent\bin\buildkite-agent.exe

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
If ($Env:BUILDKITE_AGENT_ENABLE_GIT_MIRRORS_EXPERIMENT -eq "true") {
  If ([string]::IsNullOrEmpty($Env:BUILDKITE_AGENT_EXPERIMENTS)) {
    $Env:BUILDKITE_AGENT_EXPERIMENTS = "git-mirrors"
  }
  Else {
    $Env:BUILDKITE_AGENT_EXPERIMENTS += ",git-mirrors"
  }
  $Env:BUILDKITE_AGENT_GIT_MIRRORS_PATH = "C:\buildkite-agent\git-mirrors"
}

# Get token from ssm param (if we have a path)
If ($null -ne $Env:BUILDKITE_AGENT_TOKEN_PATH -and $Env:BUILDKITE_AGENT_TOKEN_PATH -ne "") {
  $Env:BUILDKITE_AGENT_TOKEN = $(aws ssm get-parameter --name $Env:BUILDKITE_AGENT_TOKEN_PATH --with-decryption --output text --query Parameter.Value --region $Env:AWS_REGION)
}

$OFS=","
Set-Content -Path C:\buildkite-agent\buildkite-agent.cfg -Value @"
name="${Env:BUILDKITE_STACK_NAME}-${Env:INSTANCE_ID}-%spawn"
token="${Env:BUILDKITE_AGENT_TOKEN}"
tags=$agent_metadata
tags-from-ec2-meta-data=true
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
"@
$OFS=" "

nssm set lifecycled AppEnvironmentExtra :AWS_REGION=$Env:AWS_REGION
nssm set lifecycled AppEnvironmentExtra +LIFECYCLED_HANDLER="C:\buildkite-agent\bin\stop-agent-gracefully.ps1"
Restart-Service lifecycled

# wait for docker to start
$next_wait_time=0
do {
  Write-Output "Sleeping $next_wait_time seconds"
  Start-Sleep -Seconds ($next_wait_time++)
  docker ps
} until ($? -OR ($next_wait_time -eq 5))

docker ps
if (! $?) {
  Write-Output "Failed to contact docker"
  exit 1
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

Write-Output "Starting the Buildkite Agent"

nssm install buildkite-agent C:\buildkite-agent\bin\buildkite-agent.exe start
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set buildkite-agent ObjectName .\$UserName $Password
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set buildkite-agent AppStdout C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set buildkite-agent AppStderr C:\buildkite-agent\buildkite-agent.log
If ($lastexitcode -ne 0) { Exit $lastexitcode }
nssm set buildkite-agent AppEnvironmentExtra :HOME=C:\buildkite-agent
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
