$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root=$script:UsbRoot
$version=(Get-Content -LiteralPath (Join-Path $root 'config/settings.example.json') -Raw | ConvertFrom-Json).app.version
$installer=Join-Path $root ('dist/Orvyn-Setup-'+$version+'.exe')
if(-not(Test-Path -LiteralPath $installer)){throw 'Build the installer first.'}
$fixture=Join-Path $root ('tests/installer-'+[guid]::NewGuid().ToString('N'))
$target=Join-Path $fixture 'Installed Orvyn'
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
function Invoke-Installer($destination,$phase){
    $arguments=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NORESTARTAPPLICATIONS','/SP-','/LANG=english','/TASKS=""',('/DIR="'+$destination+'"'),('/LOG="'+(Join-Path $fixture ($phase+'.log'))+'"'))
    $process=Start-Process -WindowStyle Hidden -FilePath $installer -ArgumentList $arguments -PassThru
    if(-not $process.WaitForExit(300000)){throw "Installer timed out: $phase"}
    $process.Refresh()
    return $process.ExitCode
}
if((Invoke-Installer $target 'fresh') -ne 0){throw 'Fresh installation failed.'}
$profile=Get-Content -LiteralPath (Join-Path $target 'config/custom-models.json') -Raw | ConvertFrom-Json
$catalog=Get-Content -LiteralPath (Join-Path $target 'config/model-catalog.json') -Raw | ConvertFrom-Json
$settingsPath=Join-Path $target 'config/settings.json'
$settings=Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
if(@($profile.models).Count -ne 1 -or $profile.models[0].id -ne 'orvyn-1' -or @($catalog.models).Count -ne 0){throw 'Unexpected installed models.'}
foreach($path in $settings.paths.PSObject.Properties){if([IO.Path]::IsPathRooted($path.Value)){throw ('Nonportable path: '+$path.Name)}}
$weights=@(Get-ChildItem -LiteralPath (Join-Path $target 'models') -Recurse -File -Filter '*.gguf')
if($weights.Count -ne 1){throw 'The installer must include exactly one model.'}
$modelPath=$weights[0].FullName
$modelHash=(Get-FileHash -LiteralPath $modelPath).Hash.ToLower()
if($modelHash -ne $profile.models[0].sha256){throw 'Installed model integrity check failed.'}
foreach($private in @('data/chats.json','config/api-providers.json')){if(Test-Path -LiteralPath (Join-Path $target $private)){throw 'Private data was included in the installer.'}}
foreach($license in @('APACHE-2.0.txt','LLAMA-3.2-LICENSE.txt','LLAMA-3.2-USE-POLICY.txt','LLAMAFILE-LICENSE.txt','NOTICE.txt')){if(-not(Test-Path -LiteralPath (Join-Path $target ('licenses/'+$license)))){throw ('Bundled license missing: '+$license)}}
if((Get-FileHash -LiteralPath (Join-Path $target 'Orvyn.exe')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root 'dist/Orvyn-portable/Orvyn.exe')).Hash){throw 'Installed executable differs from the release.'}
Write-Output 'Fresh installation passed: clean configuration, relative paths, one verified Orvyn 1 model.'

$app=Start-Process -WindowStyle Hidden -FilePath (Join-Path $target 'Orvyn.exe') -WorkingDirectory $target -PassThru
try{
    $sessionPath=Join-Path $target 'data/desktop-session.json'
    $ready=$false
    for($i=0;$i -lt 600;$i++){
        $app.Refresh();if($app.HasExited){throw 'Installed app exited before becoming ready.'}
        if(Test-Path -LiteralPath $sessionPath){
            try{$session=Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json;if($session.ui_loaded){$ready=$true;break}}catch{}
        }
        Start-Sleep -Milliseconds 200
    }
    if(-not $ready){throw 'Installed app did not finish loading its interface.'}
    $models=Invoke-RestMethod ($session.url+'/api/catalog') -Headers @{'X-AIUSB-Session'=$session.token}
    if(@($models.models.PSObject.Properties).Count -ne 1 -or -not $models.models.'orvyn-1'.installed){throw 'Installed app cannot find its included model.'}
    if(-not(Test-Path -LiteralPath (Join-Path $target 'data/webview-profile'))){throw 'WebView profile is missing from the installation folder.'}
    Write-Output 'Installed app passed: live interface, local API and bundled model recognized.'
}finally{
    if(-not $app.HasExited){$null=$app.CloseMainWindow();if(-not $app.WaitForExit(10000)){$app.Kill();$app.WaitForExit()}}
}

# Test preservation with synthetic data only; never copy personal conversations.
$settings | Add-Member -NotePropertyName installer_test_marker -NotePropertyValue 'keep my settings' -Force
[IO.File]::WriteAllText($settingsPath,($settings|ConvertTo-Json -Depth 20))
$sentinels=@{
    'data/chats.json'='{"chats":[{"id":"installer-test","title":"Keep this conversation","messages":[]}],"preferences":{"language":"English"}}'
    'config/api-providers.json'='{"providers":[],"installer_test_marker":"keep provider settings"}'
    'backups/keep.txt'='Keep this backup'
}
foreach($name in $sentinels.Keys){[IO.File]::WriteAllText((Join-Path $target $name),$sentinels[$name])}
$preserved=@{}
foreach($name in @($sentinels.Keys)+@('config/settings.json','config/custom-models.json','config/model-catalog.json')){$preserved[$name]=(Get-FileHash -LiteralPath (Join-Path $target $name)).Hash}
[IO.File]::WriteAllText((Join-Path $target 'README.txt'),'Old application file')
if((Invoke-Installer $target 'upgrade') -ne 0){throw 'Upgrade installation failed.'}
foreach($name in $preserved.Keys){if((Get-FileHash -LiteralPath (Join-Path $target $name)).Hash -ne $preserved[$name]){throw ('Upgrade changed user data: '+$name)}}
if((Get-FileHash -LiteralPath (Join-Path $target 'README.txt')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root 'dist/Orvyn-portable/README.txt')).Hash){throw 'Upgrade did not replace an application file.'}
if((Get-FileHash -LiteralPath $modelPath).Hash.ToLower() -ne $modelHash){throw 'Upgrade changed the model.'}
Write-Output 'Upgrade passed: application updated; conversations, settings, model and backups preserved.'

$blocked=Join-Path $fixture 'Protected repository'
New-Item -ItemType Directory -Path (Join-Path $blocked '.git') -Force | Out-Null
if((Invoke-Installer $blocked 'protected-folder') -eq 0 -or (Test-Path -LiteralPath (Join-Path $blocked 'Orvyn.exe'))){throw 'Installer accepted a source repository as its destination.'}
Write-Output 'Destination protection passed.'

# Uninstall only the isolated test installation, never the development USB app.
$resolved=[IO.Path]::GetFullPath($target)
$allowed=[IO.Path]::GetFullPath((Join-Path $root 'tests')).TrimEnd('\')+'\'
if(-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase) -or (Get-Item -LiteralPath $target).Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)){throw 'Unsafe test uninstall destination.'}
$uninstaller=Join-Path $resolved 'unins000.exe'
$uninstall=Start-Process -WindowStyle Hidden -FilePath $uninstaller -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',('/LOG="'+(Join-Path $fixture 'uninstall.log')+'"')) -PassThru
if(-not $uninstall.WaitForExit(120000)){throw 'Test uninstall timed out.'}
$uninstall.Refresh()
if($uninstall.ExitCode -ne 0){throw 'Test uninstall failed.'}
foreach($name in $preserved.Keys){if((Get-FileHash -LiteralPath (Join-Path $target $name)).Hash -ne $preserved[$name]){throw ('Uninstall removed user data: '+$name)}}
if((Get-FileHash -LiteralPath $modelPath).Hash.ToLower() -ne $modelHash){throw 'Uninstall removed the model.'}
if(Test-Path -LiteralPath (Join-Path $target 'Orvyn.exe')){throw 'Uninstall did not remove the application.'}
Write-Output 'Uninstall passed: app removed; conversations, settings, model and backups preserved.'
$result=@{passed=$true;version=$version;fixture=$fixture;installer_sha256=(Get-FileHash -LiteralPath $installer).Hash.ToLower();checks=@('fresh install','model integrity','live app and catalog','upgrade and user data preservation','protected destination','uninstall and user data preservation')}
[IO.File]::WriteAllText((Join-Path $fixture 'result.json'),($result|ConvertTo-Json -Depth 5))
Write-Output ('Installer tests passed: '+$fixture)
