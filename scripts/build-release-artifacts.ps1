param([Parameter(Mandatory)][string]$Compiler)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root = $script:UsbRoot

$commit = & git -C $root rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $commit -notmatch '^[a-f0-9]{40}$') { throw 'Cannot determine source commit.' }
if ($env:GITHUB_ACTIONS -eq 'true' -and $commit -ne $env:GITHUB_SHA) {
    throw 'Checked-out commit differs from the workflow source commit.'
}
$version = (Get-Content -LiteralPath (Join-Path $root 'config/settings.example.json') -Raw | ConvertFrom-Json).app.version
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid release version.' }

& (Join-Path $PSScriptRoot 'build-installer.ps1') -Compiler $Compiler
& (Join-Path $PSScriptRoot 'build-installer.ps1') -Compiler $Compiler -WithoutOrvyn1

$dist = Join-Path $root 'dist'
$artifact = Join-Path $dist "release-$version-$commit"
New-Item -ItemType Directory -Path $artifact -Force | Out-Null
$installers = foreach ($suffix in @('', '-No-Orvyn-1')) {
    $name = "Orvyn-Setup-$version$suffix.exe"
    $file = Get-Item -LiteralPath (Join-Path $dist $name)
    $sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    Copy-Item -LiteralPath $file.FullName -Destination $artifact -Force
    "$sha256  $name" | Set-Content -LiteralPath (Join-Path $artifact "$name.sha256") -Encoding ascii
    [ordered]@{ file = $name; bytes = $file.Length; sha256 = $sha256; includesOrvyn1 = ($suffix -eq '') }
}
[ordered]@{ version = $version; sourceCommit = $commit; installers = @($installers) } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $artifact 'build-manifest.json') -Encoding utf8

if ($env:GITHUB_OUTPUT) {
    "artifact_path=$artifact" | Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8
    "artifact_name=Orvyn-$version-$commit" | Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8
}
Write-Output "Release artifacts staged at $artifact"
