# Compatibility entry point for the current USB installer test.
$root=Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
& (Join-Path $root 'scripts/test-installer.ps1')
