param ([parameter(Mandatory=$true)][string]$From, [parameter(Mandatory=$true)][string]$To)

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

# Fetch content from various URI schemes:
# - s3://bucket/key: S3 object URI (uses AWS CLI)
# - ssm:/path/to/param: SSM parameter path (uses AWS CLI)
# - https://example.com/file: HTTPS URL (uses Invoke-WebRequest)
# - file:///path/to/file: Local file path (uses Invoke-WebRequest)
# - http://example.com/file: HTTP URL (uses Invoke-WebRequest)

If ($From -Like "s3://*") {
  # S3 object URI - use AWS CLI to fetch
  aws s3 cp $From $To
  If ($lastexitcode -ne 0) { Exit $lastexitcode }
}
ElseIf ($From -Like "ssm:*") {
  # SSM parameter path - fetch parameters recursively
  $SsmPath = $From -replace "^ssm:", ""

  # Get parameters from SSM
  $Parameters = aws ssm get-parameters-by-path `
    --path $SsmPath `
    --recursive `
    --with-decryption `
    --query 'Parameters[*].{Name: Name, Value: Value}' `
    --output json | ConvertFrom-Json

  If ($lastexitcode -ne 0) { Exit $lastexitcode }

  # Format as environment variables: KEY="value"
  $Parameters | ForEach-Object {
    $Name = ($_.Name -split "/")[-1].ToUpper()
    $Value = $_.Value
    "$Name=`"$Value`""
  } | Out-File -FilePath $To -Encoding UTF8
}
Else {
  # All other URIs (HTTPS, HTTP, file://) - use Invoke-WebRequest
  Invoke-WebRequest -Uri $From -OutFile $To
}
