param([switch]$SkipModelHash)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root=$script:UsbRoot
$target=Join-Path $root 'dist/Orvyn-portable'
$model=Join-Path $root 'models/desktop-active/llama32-1b.gguf'
$profile=Get-Content (Join-Path $root 'config/custom-models.example.json') -Raw | ConvertFrom-Json
$orvyn=$profile.models | Where-Object id -eq 'orvyn-1'
if(-not $orvyn -or -not(Test-Path -LiteralPath $model)){throw 'Orvyn 1 is required for the portable package.'}
if(-not $SkipModelHash -and (Get-FileHash -LiteralPath $model -Algorithm SHA256).Hash.ToLower() -ne $orvyn.sha256){throw 'Orvyn 1 integrity check failed.'}
foreach($folder in @('config','data','logs','backups','models/desktop-active','runtime/llamafile','apps/web-ui/dist')){New-Item -ItemType Directory -Path (Join-Path $target $folder) -Force | Out-Null}
function Copy-PackageFile($source,$destination){
    $from=Join-Path $root $source;$to=Join-Path $target $destination
    if(-not(Test-Path -LiteralPath $from)){throw "Package input missing: $source"}
    $existing=Get-Item -LiteralPath $to -ErrorAction SilentlyContinue;$original=Get-Item -LiteralPath $from
    if(-not $existing -or $existing.Length -ne $original.Length -or $existing.LastWriteTimeUtc -ne $original.LastWriteTimeUtc){Copy-Item -LiteralPath $from -Destination $to -Force}
}
Copy-PackageFile 'dist/AI-USB.exe' 'Orvyn.exe'
Copy-PackageFile 'dist/WebView2Loader.dll' 'WebView2Loader.dll'
Copy-PackageFile 'runtime/llamafile/llamafile-0.10.6.exe' 'runtime/llamafile/llamafile-0.10.6.exe'
Copy-PackageFile 'models/desktop-active/llama32-1b.gguf' 'models/desktop-active/llama32-1b.gguf'
Copy-PackageFile 'models/desktop-active/llama32-1b.gguf.verified.json' 'models/desktop-active/llama32-1b.gguf.verified.json'
foreach($name in @('settings','custom-models','model-catalog')){Copy-PackageFile ('config/'+$name+'.example.json') ('config/'+$name+'.json')}
Copy-Item -Path (Join-Path $root 'apps/web-ui/dist/*') -Destination (Join-Path $target 'apps/web-ui/dist') -Recurse -Force
[IO.File]::WriteAllText((Join-Path $target 'START.bat'),"@echo off`r`nstart `"`" `"%~dp0Orvyn.exe`"`r`n",[Text.Encoding]::ASCII)
[IO.File]::WriteAllText((Join-Path $target 'README.txt'),'Start Orvyn.exe or START.bat. Keep this folder together: Orvyn 1 is included beside the executable, not embedded in it. No model download is required. The Windows WebView2 runtime is required. Conversations are stored under data. This package does not copy your conversations, API keys, or training data. Model: Llama 3.2 1B Instruct Q4_K_M, distributed by the original publisher under its own license. Source: '+$orvyn.url)
Write-Output "Portable app with Orvyn 1 included: $target"
