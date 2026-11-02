$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'usb-environment.ps1')
$root=$script:UsbRoot
$test=Join-Path $root ('tests\lifecycle-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $test,(Join-Path $test 'config'),(Join-Path $test 'logs') -Force | Out-Null
$cfg=Get-Content -LiteralPath (Join-Path $root 'config\settings.json') -Raw | ConvertFrom-Json
$cfg.model_policy.idle_seconds=3
foreach($property in $cfg.paths.PSObject.Properties){
    if($property.Name -in @('data','backups','logs')){$property.Value=$property.Name}
    else{$property.Value=Join-Path $root $property.Value}
}
$port=19080
foreach($svc in $cfg.services.PSObject.Properties){
    $svc.Value.port=$port;$port++
    $svc.Value.command=Join-Path $root $svc.Value.command
    for($i=0;$i -lt $svc.Value.args.Count;$i++){if($svc.Value.args[$i].EndsWith('.gguf')){$svc.Value.args[$i]=Join-Path $root $svc.Value.args[$i]}}
}
[IO.File]::WriteAllText((Join-Path $test 'config\settings.json'),($cfg|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
$release=Join-Path $root 'apps\manager\build-usb\release'
Copy-Item -LiteralPath (Join-Path $release 'ai-usb-manager.exe') -Destination (Join-Path $test 'AI-USB.exe')
Copy-Item -LiteralPath (Join-Path $release 'WebView2Loader.dll') -Destination $test
$app=Start-Process -FilePath (Join-Path $test 'AI-USB.exe') -RedirectStandardOutput (Join-Path $test 'logs\app.out') -RedirectStandardError (Join-Path $test 'logs\app.err') -PassThru
$handle=$app.Handle
try{
    $sessionFile=Join-Path $test 'data\desktop-session.json'
    for($i=0;$i -lt 60;$i++){if(Test-Path -LiteralPath $sessionFile){$session=Get-Content -LiteralPath $sessionFile -Raw|ConvertFrom-Json;if($session.ui_loaded){break}};Start-Sleep -Seconds 1}
    if(-not $session.ui_loaded){throw 'Testvenster niet gereed'}
    $headers=@{'X-AIUSB-Session'=$session.token}
    function Request($path,$body=$null){
        if($null -eq $body){return Invoke-RestMethod -Uri ($session.url+$path) -Headers $headers -TimeoutSec 15}
        Invoke-RestMethod -Uri ($session.url+$path) -Headers $headers -Method Post -Body ($body|ConvertTo-Json -Depth 20) -ContentType 'application/json' -TimeoutSec 300
    }
    function AssertOnly($id){
        $c=Request '/api/catalog'
        $loaded=@($c.models.PSObject.Properties|Where-Object{$_.Value.online})
        if($id){if($loaded.Count -ne 1 -or $loaded[0].Name -ne $id){throw "Verkeerde actieve modellen: verwacht $id"}}
        elseif($loaded.Count -ne 0){throw 'Er is onterecht een model geladen'}
    }
    AssertOnly $null
    'PASS: openen start geen AI'
    $r=Request '/api/chat' @{model='qwen3';messages=@(@{role='user';content='Wat is 2+2? Geef alleen het getal.'});max_tokens=4096}
    if($r.choices[0].message.content.Trim() -ne '4'){throw 'Qwen-chatantwoord klopt niet'}
    AssertOnly 'qwen3'
    'PASS: echte aanvraag start uitsluitend Qwen3 en antwoordt 4'
    # Use a real OCR request to exercise switching to another model.
    $image=[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $root 'tests\fixtures\test-ocr.png')))
    $r=Request '/api/chat' @{model='glm-ocr';messages=@(@{role='user';content=@(@{type='text';text='Text Recognition:'},@{type='image_url';image_url=@{url="data:image/png;base64,$image"}})});max_tokens=64}
    AssertOnly 'glm-ocr'
    'PASS: modelwissel laadt Qwen3 uit en laat alleen GLM-OCR geladen'
    Start-Sleep -Seconds 7
    AssertOnly $null
    'PASS: inactiviteit laadt het model automatisch uit'
    $requestFile=Join-Path $test 'request.json'
    [IO.File]::WriteAllText($requestFile,(@{model='qwen3';messages=@(@{role='user';content='Schrijf een zeer uitgebreid verhaal van 2000 woorden over de zee.'});max_tokens=4096}|ConvertTo-Json -Depth 6))
    $pending=Start-Process curl.exe -ArgumentList @('--silent','--show-error','--max-time','300','-H',('"X-AIUSB-Session: '+$session.token+'"'),'-H','"Content-Type: application/json"','--data-binary',('@'+$requestFile),($session.url+'/api/chat')) -RedirectStandardOutput (Join-Path $test 'cancel-response.json') -RedirectStandardError (Join-Path $test 'logs\curl.err') -PassThru
    $pendingHandle=$pending.Handle
    for($i=0;$i -lt 30;$i++){Start-Sleep -Seconds 1;$c=Request '/api/catalog';if($c.runtime.phase -in @('loading','generating')){break}}
    Request '/api/models/cancel' @{} | Out-Null
    if(-not $pending.WaitForExit(20000)){throw 'Geannuleerde aanvraag blijft hangen'}
    AssertOnly $null
    'PASS: annuleren stopt het model en de aanvraag'
    [IO.File]::WriteAllText((Join-Path $test 'result.txt'),'PASS: lazy start, response, switch, idle unload, cancellation')
}finally{
    [void]$app.CloseMainWindow();[void]$app.WaitForExit(15000)
}
"Testresultaat: $test"
