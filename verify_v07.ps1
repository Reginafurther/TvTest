param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$tests = @(
    @("--", "--v07-ui-actors-test"),
    @("--", "--v07-adventure-test"),
    @("--", "--v07-persistence-test"),
    @("--", "--v061-start-test"),
	@("--", "--v06-character-test"),
    @("--", "--v061-ai-test"),
    @("--", "--v061-skill-test"),
    @("--", "--v061-progression-test"),
    @("--", "--v061-economy-test"),
    @("--", "--v061-core-test"),
    @("--", "--v061-playtest-fixes-test"),
    @("--", "--v061-long-combat-test")
)

foreach ($argsForTest in $tests) {
    & $Godot --headless --path $PSScriptRoot @argsForTest
    if ($LASTEXITCODE -ne 0) { throw "Godot test failed: $($argsForTest -join ' ')" }
}

& $Godot --headless --path $PSScriptRoot --script "$PSScriptRoot/tests/balance_simulation.gd"
if ($LASTEXITCODE -ne 0) { throw "V0.6.1 balance regression failed" }
& $Godot --headless --path $PSScriptRoot --script "$PSScriptRoot/tests/v07_balance_simulation.gd"
if ($LASTEXITCODE -ne 0) { throw "V0.7 balance simulation failed" }

Write-Host "V07_FULL_AUTOMATION_PASS"
