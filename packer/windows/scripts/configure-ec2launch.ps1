try {
    $configPath = "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml"

    @"
version: 1.0
config:
  - stage: boot
    tasks:
      - task: extendRootPartition

  - stage: network
    tasks:
      - task: configureWinRM
        inputs:
          http: true
          https: true
          certificateThumbprint:
            type: generate

  - stage: preReady
    tasks:
      - task: activateWindows
        inputs:
          activation:
            type: amazon
      - task: setDnsSuffix
        inputs:
          suffixes:
            - \$REGION.ec2-utilities.amazonaws.com
      - task: setAdminAccount
        inputs:
          password:
            type: random
      - task: setWallpaper
        inputs:
          path: C:\ProgramData\Amazon\EC2Launch\wallpaper\Ec2Wallpaper.jpg
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

  - stage: postReady
    tasks:
      - task: startSsm
"@ | Out-File -FilePath $configPath -Encoding utf8 -Force

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
