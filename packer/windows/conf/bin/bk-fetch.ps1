param ([parameter(Mandatory=$true)][string]$From, [parameter(Mandatory=$true)][string]$To)

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

If ($From -Like "s3://*") {
  aws s3 cp $From $To
  If ($lastexitcode -ne 0) { Exit $lastexitcode }
}
Else {
  Invoke-WebRequest -Uri $From -OutFile $To
}
