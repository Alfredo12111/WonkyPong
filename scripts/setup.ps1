$ErrorActionPreference = 'Stop'
$project = Split-Path $PSScriptRoot -Parent
$sibling = Join-Path (Split-Path $project -Parent) 'WonkyCalc/.runtimes'
$configured = $env:WONKYPONG_TOOLCHAINS
if (!$configured -and (Test-Path -LiteralPath "$project/toolchains.local.txt")) { $configured = (Get-Content "$project/toolchains.local.txt" -Raw).Trim() }
if (!$configured -and !(Test-Path -LiteralPath "$sibling/haxe")) {
    New-Item -ItemType Directory -Force -Path "$project/.cache" | Out-Null
    $source = Join-Path $project '.cache/toolchains'
    $revision = 'fec7a153bea1f889a493f7fbe40a063d379b8d88'
    if (!(Test-Path -LiteralPath "$source/.git")) {
        git clone https://github.com/Alfredo12111/WonkyCalc.git $source
        if ($LASTEXITCODE -ne 0) { throw 'Toolchain source download failed.' }
    }
    git -C $source checkout --detach $revision
    if ($LASTEXITCODE -ne 0) { throw 'Pinned toolchain checkout failed.' }
    & "$source/scripts/setup-windows.ps1"
    if ($LASTEXITCODE -ne 0) { throw 'Toolchain setup failed.' }
}
& "$PSScriptRoot/build.ps1"
