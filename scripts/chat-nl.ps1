[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$config = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\config\settings.json') -Raw | ConvertFrom-Json
$server = "http://127.0.0.1:$($config.services.qwen3.port)"
$model = "qwen3"
$system = "Je bent een behulpzame assistent. Je antwoordt ALTIJD in het Nederlands, ongeacht de taal die de gebruiker gebruikt."

try {
    Invoke-RestMethod -Uri "$server/health" -TimeoutSec 5 | Out-Null
} catch {
    Write-Host ""
    Write-Host "De modelserver op $server is niet bereikbaar." -ForegroundColor Red
    Write-Host "Start de services met START.bat op de USB." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Nederlandse chat met $model" -ForegroundColor Cyan
Write-Host "Typ je vraag (Enter). Stoppen: typ 'exit'." -ForegroundColor DarkGray
Write-Host ""

$history = New-Object System.Collections.ArrayList
[void]$history.Add(@{ role = "system"; content = $system })

while ($true) {
    Write-Host ""
    Write-Host -NoNewline "Jij: " -ForegroundColor Green
    $question = Read-Host
    if ([string]::IsNullOrWhiteSpace($question)) { continue }
    if ($question -match '^\s*(exit|quit|stop|afsluiten|weg)\s*$') { break }

    [void]$history.Add(@{ role = "user"; content = $question.Trim() })

    $payload = @{
        model    = $model
        messages = @($history.ToArray())
    } | ConvertTo-Json -Depth 10

    Write-Host -NoNewline "Model" -ForegroundColor Yellow
    $spinner = "|/-\"
    $i = 0
    $job = Start-Job -ArgumentList "$server/v1/chat/completions", $payload -ScriptBlock {
        param($url, $json)
        $r = Invoke-RestMethod -Uri $url -Method Post -Body $json -ContentType "application/json" -TimeoutSec 1200
        $r | ConvertTo-Json -Depth 20
    }

    while ($job.State -eq "Running") {
        Write-Host -NoNewline $spinner[$i % 4]
        Start-Sleep -Milliseconds 250
        Write-Host -NoNewline "`b"
        $i++
    }

    Write-Host -NoNewline "`r"
    Write-Host -NoNewline (" " * 30)
    Write-Host -NoNewline "`r"

    if ($job.State -eq "Failed" -or $job.State -eq "Stopped") {
        Write-Host "Fout bij het ophalen van het antwoord." -ForegroundColor Red
        $reason = $job.ChildJobs[0].JobStateInfo.Reason
        if ($reason) { Write-Host $reason.Message -ForegroundColor DarkRed }
        Remove-Job $job -Force
        continue
    }

    $raw = Receive-Job $job
    Remove-Job $job -Force

    try {
        $response = $raw | ConvertFrom-Json
        $answer = $response.choices[0].message.content
    } catch {
        Write-Host "Onverwacht antwoord van de server ontvangen." -ForegroundColor Red
        continue
    }

    Write-Host -NoNewline "Model: " -ForegroundColor Yellow
    Write-Host $answer
    [void]$history.Add(@{ role = "assistant"; content = $answer })
}
