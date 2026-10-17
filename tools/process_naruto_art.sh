#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
portrait_source="${project_root}/artwork/v10_naruto/source/portraits"
battle_source="${project_root}/artwork/v10_naruto/source/battles"
portrait_output="${project_root}/assets/portraits/naruto"
battle_output="${project_root}/assets/units/naruto"

mkdir -p "${portrait_output}" "${battle_output}"

for source in "${portrait_source}"/*.png; do
	actor_id="$(basename "${source}" .png)"
	magick "${source}" \
		-trim +repage -bordercolor none -border 12 \
		-filter Lanczos -resize '600x900>' \
		-gravity center -background none -extent 640x960 \
		-define png:compression-level=9 \
		"${portrait_output}/${actor_id}_portrait_v1.png"
done

for source in "${battle_source}"/*.png; do
	actor_id="$(basename "${source}" .png)"
	magick "${source}" \
		-trim +repage -bordercolor none -border 8 \
		-filter Lanczos -resize '480x480>' \
		-gravity south -background none -extent 512x512 \
		-define png:compression-level=9 \
		"${battle_output}/${actor_id}_battle_v1.png"
done

echo "Processed 10 Naruto portraits and 10 battle sprites."
