$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach($name in @('settings','custom-models','model-catalog')){
    $target=Join-Path $root ('config/'+$name+'.json')
    if(-not(Test-Path -LiteralPath $target)){Copy-Item -LiteralPath (Join-Path $root ('config/'+$name+'.example.json')) -Destination $target}
}
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
foreach($name in @('data','models/desktop-active','backups','logs','runtime/llamafile','dist')){New-Item -ItemType Directory -Path (Join-Path $root $name) -Force | Out-Null}
Write-Output 'Portable configuration is ready. Existing configuration and personal data were preserved.'
