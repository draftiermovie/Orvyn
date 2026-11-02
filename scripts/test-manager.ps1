$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$toolchain=Join-Path $script:UsbRoot 'tools/llvm-mingw-20260922-msvcrt-x86_64/bin'
$env:RUSTFLAGS='-C dlltool='+(Join-Path $toolchain 'llvm-dlltool.exe')+' -C link-arg=-B'+$toolchain+'\'
& "$env:USERPROFILE\.cargo\bin\cargo.exe" test --manifest-path (Join-Path $script:UsbRoot 'apps/manager/Cargo.toml') --release --locked --offline --jobs 4 --target-dir (Join-Path $script:UsbRoot 'apps/manager/build-usb') -- --test-threads=2
if($LASTEXITCODE -ne 0){throw 'Rust-tests mislukt'}
