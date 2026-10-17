#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$PROJECT_ROOT/artwork/v15_huangyi_fengyun/source"

declare -A HUANGYI_IDS=(
  [hy_longying]=hy_long_ying [hy_wuzhao]=hy_wu_zhao
  [hy_kouzhong]=hy_kou_zhong [hy_xuziling]=hy_xu_ziling
  [hy_wanwan]=hy_wan_wan [hy_faming]=hy_fa_ming
  [hy_yanfei]=hy_yan_fei [hy_sunen]=hy_sun_en
  [hy_lingdonglai]=hy_ling_donglai [hy_langfanyun]=hy_lang_fanyun
)

declare -A FENGYUN_IDS=(
  [fy_niefeng]=fy_nie_feng [fy_bujingyun]=fy_bu_jingyun
  [fy_wuming]=fy_wuming [fy_jiansheng]=fy_sword_saint
  [fy_wuwudi]=fy_wu_wudi [fy_xiaowu]=fy_xiao_wu
  [fy_duanlang]=fy_duan_lang [fy_diermeng]=fy_di_er_meng
  [fy_jianchen]=fy_jian_chen [fy_dishitian]=fy_di_shitian
)

process_world() {
  local world="$1"
  local mapping_name="$2"
  local -n mapping="$mapping_name"
  local portrait_output="$PROJECT_ROOT/assets/portraits/$world"
  local unit_output="$PROJECT_ROOT/assets/units/$world"
  mkdir -p "$portrait_output" "$unit_output"
  for source_id in "${!mapping[@]}"; do
    local actor_id="${mapping[$source_id]}"
    magick "$SOURCE_ROOT/$world/portraits/$source_id.png" \
      -trim +repage -bordercolor none -border 16 \
      -filter Lanczos -resize '600x900>' \
      -gravity center -background none -extent 640x960 \
      -define png:color-type=6 "$portrait_output/${actor_id}_portrait_v1.png"
    magick "$SOURCE_ROOT/$world/battles/$source_id.png" \
      -trim +repage -bordercolor none -border 10 \
      -filter Lanczos -resize '480x480>' \
      -gravity south -background none -extent 512x512 \
      -define png:color-type=6 "$unit_output/${actor_id}_battle_v1.png"
  done
}

process_world huangyi HUANGYI_IDS
process_world fengyun FENGYUN_IDS
