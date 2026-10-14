param([string]$GodotBin = $env:GODOT_BIN)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($GodotBin)) { $GodotBin = 'godot' }
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$tests = @(
  '--v061-start-test',
  '--v061-ai-test',
  '--v061-exclusive-skill-test',
  '--v061-skill-test',
  '--v061-progression-test',
  '--v061-economy-test',
  '--v061-core-test',
  '--v061-playtest-fixes-test',
  '--v061-long-combat-test'
)

foreach ($test in $tests) {
  Write-Host "Running $test"
  & $GodotBin --headless --path $root -- $test
  if ($LASTEXITCODE -ne 0) { throw "$test failed with exit code $LASTEXITCODE" }
}

& $GodotBin --headless --path $root --script 'res://tests/balance_simulation.gd'
if ($LASTEXITCODE -ne 0) { throw "balance matrix failed with exit code $LASTEXITCODE" }
Write-Host 'V0.6.1 playtest-fix regression passed.'
