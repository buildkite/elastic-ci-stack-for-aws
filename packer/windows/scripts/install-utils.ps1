# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

Write-Output "Installing chocolatey package manager"
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

Write-Output "Installing awscli"
# pinned because awscli v2 drops 'aws ecr get-login'
# https://github.com/buildkite-plugins/ecr-buildkite-plugin/issues/37
choco install -y awscli --version=1.18.11
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Installing Git for Windows"
choco install -y git --version 2.31.0
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Installing nssm"
choco install -y nssm
If ($lastexitcode -ne 0) { Exit $lastexitcode }

# Make `Update-SessionEnvironment` available
Write-Output "Importing the Chocolatey profile module"
$ChocolateyInstall = Convert-Path "$((Get-Command choco).path)\..\.."
Import-Module "$ChocolateyInstall\helpers\chocolateyProfile.psm1"

Write-Output "Refreshing the current PowerShell session's environment"
Update-SessionEnvironment

# The '/GitAndUnixToolsOnPath' install parameter was appending Git for Windows paths to the system's PATH
# This caused the 'C:\Windows\system32\sort.exe' command to be used by buildkite plugins instead of
# the desired GNU coreutils '/usr/bin/sort.exe' included in Git for Windows.
# 'C:\Windows\system32\sort.exe' appends '\r\n' for each line of output instead of just '\n'.
# The unexpected '\r' breaks the parsing of some buildkite plugins including the docker-login plugin.
Write-Output "Prepending 'gitinstall\mingw64\bin' and 'gitinstall\usr\bin' to the system's PATH"
$oldpath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
$newpath = "C:\Program Files\Git\mingw64\bin;C:\Program Files\Git\usr\bin;$oldpath"
Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH -Value $newPath

# Set autocrlf to false so we don't end up with mismatched line endings
git config --system core.autocrlf false
If ($lastexitcode -ne 0) { Exit $lastexitcode }

# disable Git Credential Manager for Windows so it doesn't interfere with buildkite's secrets plugin
git config --system --unset credential.helper
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Write-Output "Configuring awscli to use v4 signatures..."
$Env:AWS_CONFIG_FILE = "C:\buildkite-agent\.aws\config"
$Env:AWS_SHARED_CREDENTIALS_FILE = "C:\buildkite-agent\.aws\credentials"
aws configure set s3.signature_version s3v4
If ($lastexitcode -ne 0) { Exit $lastexitcode }
Remove-Item -Path Env:AWS_CONFIG_FILE
Remove-Item -Path Env:AWS_SHARED_CREDENTIALS_FILE
