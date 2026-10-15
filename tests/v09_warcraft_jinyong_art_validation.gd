extends SceneTree

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const WARCRAFT_IDS := [
	"varian_wrynn", "anduin_wrynn", "thrall", "arthas_menethil",
	"illidan_stormrage", "jaina_proudmoore"
]
const JINYONG_IDS := [
	"guo_jing", "huang_rong", "yang_guo", "xiaolongnu", "zhang_wuji",
	"zhou_zhiruo", "qiao_feng", "duan_yu", "linghu_chong", "ren_yingying"
]

func _initialize() -> void:
	var failures: Array[String] = []
	var art = _read_json("res://data/art_resources.json")
	var warcraft = _read_json("res://data/v09_wow_content.json")
	var jinyong = _read_json("res://data/v09_jinyong_content.json")
	if art.is_empty() or warcraft.is_empty() or jinyong.is_empty():
		push_error("V09_WARCRAFT_JINYONG_ART_VALIDATION_FAIL: invalid JSON")
		quit(1)
		return
	ArtCatalogScript.reload()
	for actor_id in WARCRAFT_IDS:
		_validate_actor(actor_id, warcraft.get("actors", {}), art, failures)
	for actor_id in JINYONG_IDS:
		_validate_actor(actor_id, jinyong.get("actors", {}), art, failures)
	if failures.is_empty():
		print("V09_WARCRAFT_JINYONG_ART_VALIDATION_PASS actors=16 portraits=16 units=16 alpha=true resources=true")
		quit(0)
		return
	for failure in failures:
		push_error("V09_WARCRAFT_JINYONG_ART_VALIDATION_FAIL: " + failure)
	quit(1)

func _read_json(path: String) -> Dictionary:
	var value = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _validate_actor(actor_id: String, actors: Dictionary, art: Dictionary, failures: Array[String]) -> void:
	if not actors.has(actor_id):
		failures.append("unknown actor id: " + actor_id)
	for group in ["portraits", "units"]:
		var path := str(art.get(group, {}).get(actor_id, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			failures.append("missing %s path: %s" % [group, actor_id])
			continue
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) != OK or image.is_empty():
			failures.append("unreadable %s: %s" % [group, actor_id])
			continue
		if image.detect_alpha() == Image.ALPHA_NONE:
			failures.append("missing alpha: %s/%s" % [group, actor_id])
		if ArtCatalogScript.texture(group, actor_id) == null:
			failures.append("ArtCatalog failed: %s/%s" % [group, actor_id])
	var portrait_layout = art.get("portraits_layouts", {}).get(actor_id, {})
	if typeof(portrait_layout) != TYPE_DICTIONARY or portrait_layout.is_empty():
		failures.append("missing portrait layout: " + actor_id)
	var unit_layout = art.get("units_layouts", {}).get(actor_id, {})
	if typeof(unit_layout) != TYPE_DICTIONARY or unit_layout.is_empty():
		failures.append("missing unit layout: " + actor_id)
	elif float(unit_layout.get("width", 0)) <= 0.0 or float(unit_layout.get("height", 0)) <= 0.0:
		failures.append("invalid unit size: " + actor_id)
	elif unit_layout.get("anchor", []).size() != 2 or float(unit_layout.anchor[1]) < 0.85 or float(unit_layout.anchor[1]) > 1.0:
		failures.append("unsafe unit foot anchor: " + actor_id)
