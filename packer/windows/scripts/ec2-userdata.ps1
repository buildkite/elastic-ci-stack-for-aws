<persist>true</persist>
<powershell>
Start-Transcript

write-output "Running User Data Script"
write-host "(host) Running User Data Script"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# Remove HTTP listener
Remove-Item -Path WSMan:\Localhost\listener\listener* -Recurse

$Cert = New-SelfSignedCertificate -CertstoreLocation Cert:\LocalMachine\My -DnsName "packer"
New-Item -Path WSMan:\LocalHost\Listener -Transport HTTPS -Address * -CertificateThumbPrint $Cert.Thumbprint -Force

# WinRM
write-output "Setting up WinRM"
write-host "(host) setting up WinRM"

winrm set "winrm/config" '@{MaxTimeoutms="1800000"}'
If ($lastexitcode -ne 0) { Exit $lastexitcode }
winrm set "winrm/config/winrs" '@{MaxMemoryPerShellMB="1024"}'
If ($lastexitcode -ne 0) { Exit $lastexitcode }
winrm set "winrm/config/service/auth" '@{Basic="true"}'
If ($lastexitcode -ne 0) { Exit $lastexitcode }
netsh advfirewall firewall add rule name="Port 5986" protocol=TCP dir=in localport=5986 action=allow
If ($lastexitcode -ne 0) { Exit $lastexitcode }

Stop-Transcript
</powershell>
