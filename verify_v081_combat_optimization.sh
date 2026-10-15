#!/usr/bin/env bash
set -euo pipefail

task_cache_root="${TMPDIR:-/tmp}/wanjie-godot-v081"
mkdir -p "$task_cache_root/data" "$task_cache_root/config" "$task_cache_root/cache"
XDG_DATA_HOME="$task_cache_root/data" \
XDG_CONFIG_HOME="$task_cache_root/config" \
XDG_CACHE_HOME="$task_cache_root/cache" \
godot4 --headless --path . --script res://tests/v081_combat_optimization_validation.gd
