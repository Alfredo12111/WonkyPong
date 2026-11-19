$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$candidates = @($env:WONKYPONG_TOOLCHAINS)
if (Test-Path "$project/toolchains.local.txt") { $candidates += (Get-Content "$project/toolchains.local.txt" -Raw).Trim() }
$candidates += (Join-Path (Split-Path $project -Parent) 'WonkyCalc/.runtimes')
$candidates += "$project/.cache/toolchains/.runtimes"
$toolchains = $candidates | Where-Object { $_ -and (Test-Path -LiteralPath "$_/haxe") } | Select-Object -First 1
if (!$toolchains) { throw 'Toolchains not found. Run npm run setup, or set WONKYPONG_TOOLCHAINS to WonkyCalc/.runtimes.' }
$toolchains = (Resolve-Path -LiteralPath $toolchains).Path
$haxe = (Get-ChildItem -LiteralPath "$toolchains/haxe" -Filter haxe.exe -File -Recurse | Select-Object -First 1).FullName
