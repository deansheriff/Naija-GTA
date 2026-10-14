param([ValidateSet('web','android','all','test')][string]$Target = 'all')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = Join-Path $projectRoot '.tools\godot\Godot_v4.6.3-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $enginePath)) { throw 'Run python scripts/fetch_godot.py first.' }
$gamePath = Join-Path $projectRoot 'game'
New-Item -ItemType Directory -Path (Join-Path $gamePath 'story') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'server/src/prologue.json') -Destination (Join-Path $gamePath 'story/prologue.json') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'server/src/tunde-intro.json') -Destination (Join-Path $gamePath 'story/tunde-intro.json') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'server/src/ngozi-intro.json') -Destination (Join-Path $gamePath 'story/ngozi-intro.json') -Force
& $enginePath --headless --path $gamePath --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed.' }
& $enginePath --headless --path $gamePath --script res://main.gd --check-only
if ($LASTEXITCODE -ne 0) { throw 'Game script compilation failed.' }
& $enginePath --headless --path $gamePath --script (Join-Path $PSScriptRoot 'export_review_catalogue.gd') -- --test
if ($LASTEXITCODE -ne 0) { throw 'Street dialogue review export failed.' }
& $enginePath --headless --path $gamePath --script (Join-Path $PSScriptRoot 'measure_sprite_atlases.gd')
if ($LASTEXITCODE -ne 0) { throw 'Sprite alpha measurement failed.' }
& $enginePath --headless --path $gamePath --script (Join-Path $PSScriptRoot 'measure_environment_atlas.gd')
if ($LASTEXITCODE -ne 0) { throw 'Environment alpha measurement failed.' }
& $enginePath --headless --path $gamePath --script res://tests/simulation_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Simulation checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/street_activity_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Street activity checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/actor_visual_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Actor/nature checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/district_layout_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'District collision/navigation checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/world_travel_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Seeded world/vehicle travel checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/npc_routines_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'NPC routine/relationship checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/operations_client_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Owner settings/client checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/layout_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Scene layout check failed.' }
& $enginePath --headless --path $gamePath --script res://tests/career_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Career and home inventory checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/errand_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Neighbourhood errand checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/repair_task_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Interactive radio checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/campaign_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Campaign checkpoint/scene checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/driving_campaign_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Tunde driving/checkpoint checks failed.' }
& $enginePath --headless --path $gamePath --script res://tests/ngozi_campaign_test.gd -- --test
if ($LASTEXITCODE -ne 0) { throw 'Ngozi record/checkpoint checks failed.' }
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
