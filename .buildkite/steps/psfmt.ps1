Get-ChildItem -Path .\ -Filter *.ps1 -Recurse -File | ForEach-Object {
  $file = $_.FullName
  $script = Get-Content -Raw $_
  $formatted = Invoke-Formatter -ScriptDefinition $script
  If ($script -ne $formatted) {
    Write-Output "File $file needs to be formatted"
  }
}
