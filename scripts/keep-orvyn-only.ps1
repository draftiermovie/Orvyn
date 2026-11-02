param([switch]$Apply)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root=(Resolve-Path -LiteralPath $script:UsbRoot).Path.TrimEnd('\')
$keep=(Resolve-Path -LiteralPath (Join-Path $root 'models/desktop-active/llama32-1b.gguf')).Path
$expected='6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83'
if((Get-FileHash -LiteralPath $keep -Algorithm SHA256).Hash.ToLower() -ne $expected){throw 'Orvyn 1 integrity check failed. No models have been removed.'}
$areas=@('models','archive/test-models','archive/model-downloads')
$candidates=@(foreach($area in $areas){
    $parent=Join-Path $root $area
    if(-not(Test-Path -LiteralPath $parent)){continue}
    Get-ChildItem -LiteralPath $parent -Recurse -File | Where-Object {
        $_.FullName -ne $keep -and $_.FullName -ne ($keep+'.verified.json') -and
        -not $_.FullName.StartsWith((Join-Path $root 'models/training')+'\',[StringComparison]::OrdinalIgnoreCase) -and
        ($_.Name -match '\.gguf(?:\..*)?$' -or $_.Extension -in '.safetensors','.pt','.pth')
    }
})
foreach($file in $candidates){
    $resolved=(Resolve-Path -LiteralPath $file.FullName).Path
    if(-not $resolved.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or $resolved -eq $keep -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Unsafe removal target: $resolved"}
}
$bytes=($candidates|Measure-Object Length -Sum).Sum
if(-not $Apply){$candidates|Select-Object FullName,Length;Write-Output "Plan: $($candidates.Count) model-related files, $bytes bytes. Orvyn 1 and its training candidates are preserved.";return}
$record=Join-Path $root ('logs/model-cleanup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.json')
[IO.File]::WriteAllText($record,(@{kept=$keep;kept_sha256=$expected;removed=@($candidates|ForEach-Object{@{path=$_.FullName;bytes=$_.Length}});total_bytes=$bytes}|ConvertTo-Json -Depth 6))
foreach($file in $candidates){Remove-Item -LiteralPath $file.FullName -Force}
Write-Output "Removed $($candidates.Count) model-related files ($bytes bytes). Orvyn 1 preserved. Record: $record"
