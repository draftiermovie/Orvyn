$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root=$script:UsbRoot
$fixture=Join-Path $root ('tests/bundled-model-'+[guid]::NewGuid().ToString('N'))
foreach($dir in @('config','data','logs','backups')){New-Item -ItemType Directory -Path (Join-Path $fixture $dir) -Force | Out-Null}
Copy-Item -LiteralPath (Join-Path $root 'apps/manager/build-usb/release/ai-usb-manager.exe') -Destination (Join-Path $fixture 'Orvyn.exe')
Copy-Item -LiteralPath (Join-Path $root 'apps/manager/build-usb/release/WebView2Loader.dll') -Destination $fixture
foreach($name in @('custom-models','model-catalog')){Copy-Item -LiteralPath (Join-Path $root ('config/'+$name+'.example.json')) -Destination (Join-Path $fixture ('config/'+$name+'.json'))}
$settings=Get-Content (Join-Path $root 'config/settings.example.json') -Raw | ConvertFrom-Json -AsHashtable
$settings.paths.models=Join-Path $root 'models/desktop-active'
$settings.paths.llamafile=Join-Path $root 'runtime/llamafile/llamafile-0.10.6.exe'
$settings.paths.web_ui=Join-Path $root 'apps/web-ui/dist'
$listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,0);$listener.Start();$port=$listener.LocalEndpoint.Port;$listener.Stop()
$settings.services=@{'orvyn-1'=@{name='Orvyn 1';port=$port;command=$settings.paths.llamafile;args=@('--server','--model',(Join-Path $settings.paths.models 'llama32-1b.gguf'),'--host','127.0.0.1','--port',[string]$port,'--ctx-size','4096','--n-predict','512','--gpu','disable','--parallel','1','--nologo')}}
[IO.File]::WriteAllText((Join-Path $fixture 'config/settings.json'),($settings|ConvertTo-Json -Depth 15))
$process=Start-Process -WindowStyle Hidden -FilePath (Join-Path $fixture 'Orvyn.exe') -PassThru
try{
    $sessionPath=Join-Path $fixture 'data/desktop-session.json'
    for($i=0;$i -lt 150 -and -not(Test-Path -LiteralPath $sessionPath);$i++){Start-Sleep -Milliseconds 200}
    $session=Get-Content -LiteralPath $sessionPath -Raw | ConvertFrom-Json
    $headers=@{'X-AIUSB-Session'=$session.token}
    $catalog=Invoke-RestMethod ($session.url+'/api/catalog') -Headers $headers
    if(@($catalog.models.psobject.Properties).Count -ne 1 -or -not $catalog.models.'orvyn-1'.installed){throw 'The clean distribution must contain only the installed Orvyn 1 model.'}
    $body=@{model='orvyn-1';messages=@(@{role='user';content='What is your name? Answer in one short English sentence.'});max_tokens=48}|ConvertTo-Json -Depth 5
    $reply=Invoke-RestMethod ($session.url+'/api/chat') -Headers $headers -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 300
    $answer=$reply.choices[0].message.content
    if($answer -notmatch 'Orvyn 1' -or $answer -notmatch '\b(I|My|am|name)\b'){throw 'The English Orvyn 1 identity response was not recognized.'}
    Write-Output ('Included model check passed: Orvyn 1 is the only local catalog model. Live reply: '+$answer)
}finally{
    if(-not $process.HasExited){$null=$process.CloseMainWindow();if(-not $process.WaitForExit(10000)){$process.Kill();$process.WaitForExit()}}
    Write-Output ('Isolated model test: '+$fixture)
}
