$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root = Split-Path $PSScriptRoot -Parent
$tools = Join-Path $root 'tools\llvm-mingw-20260922-msvcrt-x86_64\bin'
$env:RUSTFLAGS = '-C dlltool=' + (Join-Path $tools 'llvm-dlltool.exe') + ' -C link-arg=-B' + $tools + '\'
# Run from apps\manager; paths are derived from the USB, not a fixed drive letter.
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --manifest-path (Join-Path $root 'apps\manager\Cargo.toml') --release --locked --offline --jobs 4 --target-dir (Join-Path $root 'apps\manager\build-usb')
if ($LASTEXITCODE -ne 0) { throw 'Rust build failed' }
$release=Join-Path $root 'apps\manager\build-usb\release'
$loaders=@(Get-ChildItem -LiteralPath (Join-Path $release 'build') -Recurse -Filter WebView2Loader.dll | Where-Object { $_.Directory.Name -eq 'x64' })
if(-not $loaders.Count){throw 'WebView2 loader is missing'}
Copy-Item -LiteralPath $loaders[0].FullName -Destination (Join-Path $release 'WebView2Loader.dll') -Force
