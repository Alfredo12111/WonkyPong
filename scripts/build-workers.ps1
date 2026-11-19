. "$PSScriptRoot/toolchains.ps1"
$destination = Join-Path $project '.build/native'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$destination = (Resolve-Path -LiteralPath $destination).Path
$eiffel = Join-Path $destination 'eiffel-build'
New-Item -ItemType Directory -Force -Path $eiffel | Out-Null
Copy-Item "$project/workers/eiffel/*" $eiffel -Force
$env:GOBO = Join-Path $toolchains 'gobo/gobo'
$env:ZIG = 'zig'
$env:PATH = "$env:GOBO/tool/gec/backend/c/zig;$toolchains/msys64/ucrt64/bin;$env:PATH"
Push-Location -LiteralPath $eiffel
try {
    & "$env:GOBO/bin/gec.exe" --gc=no --no-benchmark system.ecf
    if ($LASTEXITCODE -ne 0) { throw 'Eiffel compilation failed.' }
    Copy-Item senator.exe "$destination/eiffel.exe" -Force
} finally { Pop-Location }
Copy-Item "$project/workers/icon.icn" $destination -Force
Copy-Item "$project/workers/mercury.m" $destination -Force
Push-Location -LiteralPath $destination
try {
    & "$toolchains/icon/app/bin/icont.exe" -o icon.exe icon.icn
    if ($LASTEXITCODE -ne 0) { throw 'Icon compilation failed.' }
} finally { Pop-Location }
$env:MSYSTEM = 'UCRT64'
$env:CHERE_INVOKING = '1'
$env:WONKYPONG_BUILD_OUTPUT = $destination
Push-Location -LiteralPath $project
try {
    & "$toolchains/msys64/usr/bin/bash.exe" -lc 'bash scripts/compile-mercury.sh'
    if ($LASTEXITCODE -ne 0) { throw 'Mercury compilation failed.' }
} finally { Pop-Location }
Copy-Item "$toolchains/msys64/ucrt64/bin/libwinpthread-1.dll" $destination -Force
Write-Host 'Built native Eiffel, Mercury, and Icon workers.'
