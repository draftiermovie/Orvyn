$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root = $script:UsbRoot

function Get-VerifiedFile([string]$Url, [string]$Sha256, [string]$Destination) {
    if ($Sha256 -notmatch '^[a-f0-9]{64}$' -or $Url -notmatch '^https://') {
        throw 'Release inputs require an HTTPS URL and a SHA-256 digest.'
    }
    if ((Test-Path -LiteralPath $Destination -PathType Leaf) -and
        (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash -eq $Sha256) {
        return
    }
    $partial = "$Destination.download"
    try {
        & curl.exe --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 30 --output $partial -- $Url
        if ($LASTEXITCODE -ne 0) { throw "Download failed: $Url" }
        if ((Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash -ne $Sha256) {
            throw "SHA-256 mismatch: $Url"
        }
        Move-Item -LiteralPath $partial -Destination $Destination -Force
    } finally {
        if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }
    }
}

$runtime = Join-Path $root 'runtime/llamafile/llamafile-0.10.6.exe'
Get-VerifiedFile 'https://github.com/mozilla-ai/llamafile/releases/download/0.10.6/llamafile-0.10.6' `
    'd579f61dcd3a306f518e6d90e599d77793ed5f09543023d09c96ad35fcfa63f0' $runtime

$catalog = Get-Content -LiteralPath (Join-Path $root 'config/custom-models.example.json') -Raw | ConvertFrom-Json
$model = $catalog.models | Where-Object id -eq 'orvyn-1'
if (-not $model -or $model.file -ne 'llama32-1b.gguf') { throw 'Expected the bundled Orvyn 1 profile.' }
$weights = Join-Path $root 'models/desktop-active/llama32-1b.gguf'
Get-VerifiedFile $model.url $model.sha256 $weights
@{ sha256 = $model.sha256; url = $model.url } | ConvertTo-Json | Set-Content -LiteralPath "$weights.verified.json" -Encoding utf8

$setup = Join-Path $root 'tools/temp/innosetup-6.7.4.exe'
Get-VerifiedFile 'https://github.com/jrsoftware/issrc/releases/download/is-6_7_4/innosetup-6.7.4.exe' `
    'a549929319f9120716677c685535ca4671e4b937b5fdc87e2585f32d8eb30e8c' $setup
$compilerDirectory = Join-Path $root 'tools/innosetup-6.7.4'
$process = Start-Process -WindowStyle Hidden -FilePath $setup -ArgumentList @(
    '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/TASKS=""', ('/DIR="' + $compilerDirectory + '"')
) -Wait -PassThru
if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $compilerDirectory 'ISCC.exe'))) {
    throw 'Inno Setup compiler installation failed.'
}
