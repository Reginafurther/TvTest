param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$tests = @(
    @("--", "--v08-content-test"),
    @("--", "--v08-skills-test"),
    @("--", "--v08-systems-test"),
    @("--", "--v07-ui-actors-test"),
    @("--", "--v07-adventure-test"),
    @("--", "--v07-persistence-test"),
    @("--", "--v061-ai-test"),
    @("--", "--v061-skill-test"),
    @("--", "--v061-core-test"),
    @("--", "--v061-playtest-fixes-test"),
    @("--", "--v061-long-combat-test")
)

foreach ($argsForTest in $tests) {
    & $Godot --headless --path $PSScriptRoot @argsForTest
    if ($LASTEXITCODE -ne 0) { throw "Godot test failed: $($argsForTest -join ' ')" }
}

& $Godot --headless --path $PSScriptRoot --script "$PSScriptRoot/tests/v08_balance_simulation.gd"
if ($LASTEXITCODE -ne 0) { throw "V0.8 balance simulation failed" }

Write-Host "V08_FULL_AUTOMATION_PASS"
