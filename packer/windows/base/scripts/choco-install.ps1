# Forward the original install arguments, including version pins and checksum options.
$ErrorActionPreference = 'Stop'

for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Host "Chocolatey install attempt ${attempt}/3: $args"
    choco install @args
    $exitCode = $LASTEXITCODE

    # Do not repeat successful installs or reboot requests. Return these codes
    # unchanged so the provisioning scripts retain their existing exit policy.
    # https://docs.chocolatey.org/en-us/choco/commands/install/#exit-codes
    # Package-success codes are also listed under --use-package-exit-codes.
    if ($exitCode -in @(0, 1605, 1614, 1641, 3010, 350, 1604)) {
        exit $exitCode
    }
    if ($attempt -lt 3) {
        $delay = 15 * $attempt
        Write-Warning "Chocolatey exited with code $exitCode; retrying in $delay seconds."
        Start-Sleep -Seconds $delay
    }
}

exit $exitCode
