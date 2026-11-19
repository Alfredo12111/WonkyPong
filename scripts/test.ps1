. "$PSScriptRoot/toolchains.ps1"
Push-Location -LiteralPath $project
try {
    & $haxe test.hxml
    if ($LASTEXITCODE -ne 0) { throw 'Test compilation failed.' }
    node .build/test.cjs
    if ($LASTEXITCODE -ne 0) { throw 'Pongress checks failed.' }
} finally { Pop-Location }
