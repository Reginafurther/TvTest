extends SceneTree

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const ACTOR_IDS := [
	"chen_motong", "chu_zihang", "yabuki_sakura", "lu_mingfei", "lu_mingze",
	"caesar", "eri_uesugi", "minamoto_chisei", "minamoto_chime", "zero",
	"blood_river", "iron_guard", "broken_dream", "divine_harmony", "plain_question", "nine_spirits"
]

func _initialize() -> void:
	var failures: Array[String] = []
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_resources.json"))
	if typeof(config) != TYPE_DICTIONARY:
		push_error("V09_DRAGON_NSH_PORTRAIT_VALIDATION_FAIL: invalid art_resources.json")
		quit(1)
		return
	ArtCatalogScript.reload()
	for actor_id in ACTOR_IDS:
		var path := str(config.get("portraits", {}).get(actor_id, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			failures.append("missing portrait path: " + actor_id)
			continue
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) != OK or image.is_empty():
			failures.append("unreadable portrait: " + actor_id)
			continue
		if image.get_size() != Vector2i(640, 960):
			failures.append("wrong portrait size: " + actor_id)
		if image.detect_alpha() == Image.ALPHA_NONE:
			failures.append("missing alpha channel: " + actor_id)
		var used := image.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0 or used.end.x >= image.get_width() or used.end.y >= image.get_height():
			failures.append("invalid transparent margin: " + actor_id)
		if ArtCatalogScript.portrait(actor_id) == null:
			failures.append("ArtCatalog failed: " + actor_id)
		if config.get("portraits_layouts", {}).get(actor_id, {}).is_empty():
			failures.append("missing portrait layout: " + actor_id)
	if failures.is_empty():
		print("V09_DRAGON_NSH_PORTRAIT_VALIDATION_PASS portraits=16 size=640x960 alpha=true resources=true")
		quit(0)
		return
	for failure in failures:
		push_error("V09_DRAGON_NSH_PORTRAIT_VALIDATION_FAIL: " + failure)
	quit(1)
