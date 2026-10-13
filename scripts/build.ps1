param([ValidateSet('web','android','all','test')][string]$Target = 'all')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectRoot '.tools\godot\Godot_v4.6.3-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Run python scripts/fetch_godot.py first.' }
$gamePath = Join-Path $projectRoot 'game'
& $enginePath --headless --path $gamePath --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $enginePath --headless --path $gamePath --script res://tests/simulation_test.gd
if ($LASTEXITCODE -ne 0) { throw 'Simulation checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/layout_test.gd
if ($LASTEXITCODE -ne 0) { throw 'Scene layout check failed.' }
if ($Target -eq 'test') { exit 0 }
if ($Target -in @('web','all')) {
    $webPath = Join-Path $projectRoot 'build\web\play'
    New-Item -ItemType Directory -Path $webPath -Force | Out-Null
    & $enginePath --headless --path $gamePath --export-release Web (Join-Path $webPath 'index.html')
    if ($LASTEXITCODE -ne 0) { throw 'Browser export failed.' }
    python (Join-Path $PSScriptRoot 'package_web.py')
    if ($LASTEXITCODE -ne 0) { throw 'Browser packaging failed.' }
}
if ($Target -in @('android','all')) {
    $androidPath = Join-Path $projectRoot 'build\android'
    New-Item -ItemType Directory -Path $androidPath -Force | Out-Null
    & $enginePath --headless --path $gamePath --export-debug Android (Join-Path $androidPath 'naija-street-life-debug.apk')
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed. See docs/BUILD.md for JDK/SDK setup.' }
}
