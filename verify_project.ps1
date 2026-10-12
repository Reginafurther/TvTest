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
    'data/actors.json',
    'data/skills.json'
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

$godot = Get-Command godot4, godot -ErrorAction SilentlyContinue | Select-Object -First 1
if ($godot) {
    & $godot.Source --headless --path $root --quit-after 3
    if ($LASTEXITCODE -ne 0) { throw "Godot headless validation failed with exit code $LASTEXITCODE" }
    Write-Host 'PASS: Files, data references, and Godot headless startup are valid.' -ForegroundColor Green
} else {
    Write-Host 'PASS: Files and data references are valid.' -ForegroundColor Green
    Write-Warning 'Godot is not installed or not on PATH; runtime startup was not executed.'
}
