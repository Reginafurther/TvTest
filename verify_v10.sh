#!/usr/bin/env bash
set -euo pipefail

godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot)}"
task_cache_root="${TMPDIR:-/tmp}/wanjie-godot-v10"
mkdir -p "$task_cache_root/data" "$task_cache_root/config" "$task_cache_root/cache"

run_test() {
  XDG_DATA_HOME="$task_cache_root/data" \
  XDG_CONFIG_HOME="$task_cache_root/config" \
  XDG_CACHE_HOME="$task_cache_root/cache" \
  "$godot_bin" --headless --path . --script "$1" -- "$2"
}

run_test res://tests/v10_unobstructed_ranged_ai_validation.gd --v10-ranged-ai
run_test res://tests/v10_skill_damage_stats_validation.gd --v10-skill-stats
run_test res://tests/v10_eight_worlds_validation.gd --v10-eight-worlds
