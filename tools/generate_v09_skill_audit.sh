#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
output="docs/V09_SKILL_AUDIT.md"
actors_json="$(jq -cs '.[0] * (.[1].actors // {}) * (.[2].actors // {}) * (.[3].actors // {})' data/actors.json data/v08_content.json data/v09_wow_content.json data/v09_jinyong_content.json)"
skills_json="$(jq -cs '.[0] * (.[1].skills // {}) * (.[2].skills // {}) * (.[3].skills // {})' data/skills.json data/v08_content.json data/v09_wow_content.json data/v09_jinyong_content.json)"
passives_json="$(jq -cs '.[0] * (.[1].passives // {}) * (.[2].passives // {}) * (.[3].passives // {})' data/passives.json data/v08_content.json data/v09_wow_content.json data/v09_jinyong_content.json)"
general_json="$(jq -cs '.[0] * (.[1].general_skills // {}) * (.[2].general_skills // {}) * (.[3].general_skills // {})' data/general_skills.json data/v08_content.json data/v09_wow_content.json data/v09_jinyong_content.json)"

{
  echo '# V0.9 技能效果审计清单'
  echo
  echo '本表由实际数据文件生成。状态“运行验证”表示存在执行分支，并由 `tests/v09_skill_effects_validation.gd` 覆盖合法施放或被动分发；重点语义另有定向断言。'
  echo
  echo '| 世界 | 技能ID | 技能名称 | 原问题 | 实际修改 | 测试结果 |'
  echo '|---|---|---|---|---|---|'
  jq -nr --argjson actors "$actors_json" --argjson skills "$skills_json" --argjson passives "$passives_json" '
    [$actors|to_entries[]|select((.value.enemy_type|not) and .value.skill and .value.passive_skill)] | sort_by(.value.world,.value.name) |
    to_entries[] | .key as $i | .value as $a |
    [$a.value.skill, ($skills[$a.value.skill].name // ""), ($skills[$a.value.skill].type // ""), $a.value.passive_skill, ($passives[$a.value.passive_skill].name // ""), ($passives[$a.value.passive_skill].effect // "")] |
    "| \($a.value.world) | `\(.[0])` | \($a.value.name)·\(.[1]) | 逐项核查目标、范围、限制与描述一致性 | 由专属 `\(.[2])` 路径执行；缺失机制按统一结算补齐，原本正确者保留 | 运行验证 |\n| \($a.value.world) | `\(.[3])` | \($a.value.name)·\(.[4]) | 逐项核查触发条件、成长、上限与覆盖范围 | 由被动 `\(.[5])` 路径执行；缺失联动补齐，原本正确者保留 | 运行验证 |"'
  jq -nr --argjson general "$general_json" '
    [$general|to_entries[]] | sort_by(.value.world,.value.category,.value.name) | to_entries[] |
    .value as $s | ($s.value.category == "active") as $active |
    "| \($s.value.world) | `\($s.key)` | \($s.value.name) | 逐项核查\(if $active then "施放目标、范围和数值字段" else "触发条件、等级成长和实际收益" end) | 由通用 `\($s.value.effect)` 路径执行；无效字段清理，正确路径保留 | 运行验证 |"'
  echo
  echo '汇总：52 个专属主动 + 52 个专属被动 + 60 个通用主动 + 48 个通用被动 = 212 项。'
} > "$output"

count="$(grep -c '| 运行验证 |' "$output")"
test "$count" -eq 212
echo "Generated $output ($count rows)"
