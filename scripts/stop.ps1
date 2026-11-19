$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$pidFile = Join-Path $project '.cache/server.pid'
if (!(Test-Path -LiteralPath $pidFile)) { Write-Host 'No launcher-owned WonkyPong server.'; exit 0 }
$serverPid = [int](Get-Content -LiteralPath $pidFile -Raw).Trim()
$p = Get-CimInstance Win32_Process -Filter "ProcessId=$serverPid"
$server = [IO.Path]::GetFullPath((Join-Path $project '.build/server.cjs'))
if ($p -and $p.Name -eq 'node.exe' -and $p.CommandLine.Contains('"' + $server + '"')) {
    taskkill /PID $serverPid /T /F | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop the WonkyPong process tree.' }
} elseif ($p) { throw 'PID belongs to a different process; refusing to stop it.' }
Remove-Item -LiteralPath $pidFile -Force
Write-Host 'Stopped WonkyPong.'
