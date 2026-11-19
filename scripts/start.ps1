param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$port = if ($env:PORT) { [int]$env:PORT } else { 3211 }
$url = "http://localhost:$port/"
$probe = "http://127.0.0.1:$port/api/health"
if (!(Test-Path -LiteralPath "$project/.build/server.cjs")) { & "$PSScriptRoot/build.ps1" }
$ready = $false
try { $health = Invoke-RestMethod $probe -TimeoutSec 2; $ready = $health.project -eq 'Pongress' } catch {}
if (!$ready) {
    if (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) { throw "Port $port is occupied by another application." }
    New-Item -ItemType Directory -Force -Path "$project/.cache" | Out-Null
    $node = (Get-Command node -ErrorAction Stop).Source
    $server = Join-Path $project '.build/server.cjs'
    $child = Start-Process -FilePath $node -ArgumentList @('"' + $server + '"') -WorkingDirectory $project -WindowStyle Hidden -PassThru -RedirectStandardOutput "$project/.cache/server.log" -RedirectStandardError "$project/.cache/server-error.log"
    Set-Content -LiteralPath "$project/.cache/server.pid" -Value $child.Id
    for ($attempt = 0; $attempt -lt 30 -and !$ready; $attempt++) {
        Start-Sleep -Milliseconds 200
        try { $health = Invoke-RestMethod $probe -TimeoutSec 2; $ready = $health.project -eq 'Pongress' } catch {}
        if ($child.HasExited) { throw "Pongress could not start. See .cache/server-error.log." }
    }
    if (!$ready) { throw 'Pongress did not become ready. See .cache/server-error.log.' }
}
Write-Host "Pongress is ready: $url"
if (!$NoBrowser) { Start-Process $url }
