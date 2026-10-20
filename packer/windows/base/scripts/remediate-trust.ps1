$ErrorActionPreference = 'Stop'

# Do not rely on Windows Update / online revocation checks: also cover the two
# Microsoft-only roots and code-signing paths listed by the incident report.
$trustDir = 'C:\ProgramData\Buildkite\trust'
New-Item -ItemType Directory -Force -Path $trustDir | Out-Null
Copy-Item -Recurse -Force C:\Windows\Temp\trust\* $trustDir
Get-ChildItem "$trustDir\roots\*.crt" | ForEach-Object {
    Import-Certificate -FilePath $_.FullName -CertStoreLocation Cert:\LocalMachine\Disallowed | Out-Null
}
& "$trustDir\check-trust.ps1" -SystemOnly
