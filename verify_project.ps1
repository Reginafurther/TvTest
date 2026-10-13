$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$required = @(
    'project.godot',
    'scenes/main.tscn',
    'scripts/main.gd',
    'scripts/battle_controller.gd',
    'scripts/battle_map.gd',
    'scripts/unit.gd',
    'scripts/data_loader.gd',
    'scripts/floating_text.gd',
    'scripts/effect_ring.gd',
    'scripts/equipment_generator.gd',
    'scripts/inventory_manager.gd',
    'scripts/inventory_ui.gd',
    'scripts/progression_manager.gd',
    'scripts/crafting_manager.gd',
    'scripts/combat_stats.gd',
    'scripts/v03_ui.gd',
    'scripts/tutorial_ui.gd',
    'scripts/art_catalog.gd',
    'data/actors.json',
    'data/skills.json',
    'data/equipment.json',
    'data/loot_tables.json',
    'data/worlds.json',
    'data/special_effects.json',
    'data/art_resources.json'
)

foreach ($relative in $required) {
    $path = Join-Path $root $relative
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required file: $relative"
    }
}

$actors = Get-Content -Raw -LiteralPath (Join-Path $root 'data/actors.json') | ConvertFrom-Json
$skills = Get-Content -Raw -LiteralPath (Join-Path $root 'data/skills.json') | ConvertFrom-Json
$requiredActors = @('zhao_yun', 'liu_bei', 'pikachu', 'snorlax', 'yellow_turban', 'zubat')
foreach ($id in $requiredActors) {
    if (-not $actors.PSObject.Properties.Name.Contains($id)) {
        throw "Missing actor: $id"
    }
    $skillId = $actors.$id.skill
    if (-not $skills.PSObject.Properties.Name.Contains($skillId)) {
        throw "Actor $id references missing skill: $skillId"
    }
}

$equipment = Get-Content -Raw -LiteralPath (Join-Path $root 'data/equipment.json') | ConvertFrom-Json
$requiredSlots = @('main_hand', 'off_hand', 'helmet', 'armor', 'gloves', 'boots', 'necklace', 'ring_1', 'ring_2')
$requiredAffixes = @('health', 'attack', 'defense', 'crit_chance', 'crit_damage', 'attack_speed', 'cooldown_reduction', 'physical_damage', 'elemental_damage', 'life_regen')
foreach ($slot in $requiredSlots) {
    if (-not $equipment.slots.PSObject.Properties.Name.Contains($slot)) { throw "Missing equipment slot: $slot" }
}
foreach ($affix in $requiredAffixes) {
    if (-not $equipment.affixes.PSObject.Properties.Name.Contains($affix)) { throw "Missing affix: $affix" }
}

$godotPath = $env:GODOT_BIN
if (-not $godotPath) {
    $godot = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($godot) { $godotPath = $godot.Source }
}
if ($godotPath -and (Test-Path -LiteralPath $godotPath)) {
    & $godotPath --headless --path $root -- --smoke-test
    if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --equipment-test
    if ($LASTEXITCODE -ne 0) { throw "Equipment validation failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --persistence-write
    if ($LASTEXITCODE -ne 0) { throw "Persistence write failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --persistence-read
    if ($LASTEXITCODE -ne 0) { throw "Persistence read failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --v03-test
    if ($LASTEXITCODE -ne 0) { throw "V0.3 integration validation failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --v03-persist-write
    if ($LASTEXITCODE -ne 0) { throw "V0.3 persistence write failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --v03-persist-read
    if ($LASTEXITCODE -ne 0) { throw "V0.3 persistence read failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --editor --path $root --import
    if ($LASTEXITCODE -ne 0) { throw "Godot art import failed with exit code $LASTEXITCODE" }
    & $godotPath --headless --path $root -- --v031-test
    if ($LASTEXITCODE -ne 0) { throw "V0.31 UI and onboarding validation failed with exit code $LASTEXITCODE" }
    Write-Host 'PASS: V0.1, V0.2A, V0.3 and V0.31 integration suites are valid.' -ForegroundColor Green
} else {
    Write-Host 'PASS: Files, actor/skill references, 9 slots, and 10 affix definitions are valid.' -ForegroundColor Green
    Write-Warning 'Godot was not found. Set GODOT_BIN to the Godot executable to run both runtime tests.'
}
