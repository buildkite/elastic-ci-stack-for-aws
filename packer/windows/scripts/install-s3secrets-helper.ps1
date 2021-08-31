# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

$S3_SECRETS_HELPER_VERSION = "2.1.4"

Write-Output "Downloading s3-secrets-helper v${S3_SECRETS_HELPER_VERSION}..."
Invoke-WebRequest -OutFile C:\buildkite-agent\bin\s3secrets-helper.exe -Uri "https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks/releases/download/v${S3_SECRETS_HELPER_VERSION}/s3secrets-helper-windows-amd64"
s3secrets-helper.exe
If ($lastexitcode -ne 0) { Exit $lastexitcode }
