$ErrorActionPreference = "Stop"

# Configure EC2Launch for persistence
$programFiles = $env:ProgramFiles
$ec2LaunchExe = Join-Path -Path $programFiles -ChildPath 'Amazon\EC2Launch\EC2Launch.exe'

Write-Output "Getting current EC2Launch configuration"
$config = & "$ec2LaunchExe" get-agent-config --format json | ConvertFrom-Json

$config | ConvertTo-Json -Depth 6 | Out-File -encoding UTF8 "$env:ProgramData\Amazon\EC2Launch\config\agent-config.yml"

# Add UserData execution on every boot
Write-Output "Adding UserData persistence settings"
$userDataTask = @{
    task = "executeScript"
    inputs = @{
        frequency = "always"
        type = "userData"
    }
}

$found = $false
$config.config | ForEach-Object {
    if ($_.stage -eq 'postReady') {
        foreach ($task in $_.tasks) {
            if ($task.task -eq "executeScript" -and $task.inputs.type -eq "userData") {
                $found = $true
                Write-Output "UserData task already exists, ensuring frequency is set to 'always'..."
                $task.inputs.frequency = "always"
            }
        }

        if (-not $found) {
            Write-Output "Adding UserData execution task..."
            $_.tasks += $userDataTask
        }
    }
}

Write-Output "Saving updated configuration"
$config | ConvertTo-Json -Depth 6 | Out-File -encoding UTF8 "$env:ProgramData\Amazon\EC2Launch\config\agent-config.yml"

Write-Output "Running EC2Launch"
& "$ec2LaunchExe" run

Write-Output "Running EC2Launch sysprep"
& "$ec2LaunchExe" sysprep --shutdown=false
