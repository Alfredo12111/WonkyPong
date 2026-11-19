. "$PSScriptRoot/toolchains.ps1"
New-Item -ItemType Directory -Force -Path "$project/.build" | Out-Null
Push-Location -LiteralPath $project
try {
    & $haxe build.hxml
    if ($LASTEXITCODE -ne 0) { throw 'Haxe compilation failed.' }
    & "$PSScriptRoot/build-workers.ps1"
} finally { Pop-Location }
