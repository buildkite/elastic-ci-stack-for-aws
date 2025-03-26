try {
    # Delete the default agent-config.yml and replace it with our empty version
    # EC2Launch v2 expects a specific format for this file which is different from v1
    # The error indicates it's expecting a task list rather than a map
    $configPath = "C:\ProgramData\Amazon\EC2Launch\config\agent-config.yml"
    if (Test-Path $configPath) {
        Write-Host "Backing up original agent-config.yml"
        Copy-Item -Path $configPath -Destination "$configPath.bak" -Force
    }

    # Create a properly formatted empty configuration file
    # Format: a list of tasks with ExecuteScript type
    @"
- task: executeScript
  inputs:
  - frequency: always
    type: powershell
    runAs: localSystem
    content: |
      # Placeholder script
      Write-Host "EC2Launch v2 script executed"
"@ | Out-File -FilePath $configPath -Encoding utf8 -Force

    Write-Host "Created new EC2Launch v2 configuration file at $configPath"
} catch {
    Write-Host "Error configuring EC2Launch v2: $_"
    exit 1
}
