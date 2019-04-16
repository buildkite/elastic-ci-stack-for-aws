param ([string]$should_decrement = "false")

# Stop script execution when a non-terminating error occurs
$ErrorActionPreference = "Stop"

If ($should_decrement -eq "true") {
  $should_decrement = "should"
}
Else {
  $should_decrement = "no-should"
}

$InstanceId = (Invoke-WebRequest -UseBasicParsing http://169.254.169.254/latest/meta-data/instance-id).content
$Region = (Invoke-WebRequest -UseBasicParsing http://169.254.169.254/latest/meta-data/placement/availability-zone).content -replace ".$"

aws autoscaling terminate-instance-in-auto-scaling-group --region "$Region" --instance-id "$InstanceId" "--${should_decrement}-decrement-desired-capacity"

Stop-Computer $env:computername -Force
