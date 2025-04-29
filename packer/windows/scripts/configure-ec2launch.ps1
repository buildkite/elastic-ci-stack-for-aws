try {
    $configPath = "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml"

    if (Test-Path $configPath) {
        Write-Host "Backing up original agent-config.yml to $configPath.bak"
        Copy-Item -Path $configPath -Destination "$configPath.bak" -Force
    }

    @"
version: 1.0
config:
- stage: boot
  tasks:
  - task: extendRootPartition
- stage: preReady
  tasks:
  - task: activateWindows
    inputs:
      activation:
        type: amazon
  - task: setDnsSuffix
    inputs:
      suffixes:
      - $REGION.ec2-utilities.amazonaws.com
  - task: setAdminAccount
    inputs:
      password:
        type: random
  - task: setWallpaper
    inputs:
      attributes:
      - hostName
      - instanceId
      - privateIpAddress
      - publicIpAddress
      - instanceSize
      - availabilityZone
      - architecture
      - memory
      - network
      path: C:\Windows\Web\Wallpaper\Windows\img0.jpg
- stage: postReady
  tasks:
  - task: startSsm
"@ | Out-File -FilePath $configPath -Encoding utf8 -Force

    Write-Host "Wrote EC2Launch v2 configuration file at $configPath"

    & "C:\Program Files\Amazon\EC2Launch\EC2Launch.exe" validate
    if ($LASTEXITCODE -ne 0) {
        Write-Error "EC2Launch config validation failed!"
        exit 1
    }
    Write-Host "Valid EC2Launch configuration file: $configPath"
}
catch {
    Write-Error "Error configuring EC2Launch v2: $_"
    exit 1
}
