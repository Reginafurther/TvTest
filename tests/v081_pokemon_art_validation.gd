extends SceneTree

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const POKEMON_IDS := [
	"pikachu", "lucario", "snorlax", "gengar", "mewtwo",
	"bulbasaur", "charmander", "squirtle", "gardevoir", "dragonite"
]
const EXISTING_THREE_KINGDOMS_IDS := [
	"zhao_yun", "liu_bei", "zhang_fei", "guan_yu", "lu_bu",
	"zhuge_liang", "huang_zhong", "dian_wei", "diao_chan", "zhou_yu"
]

func _initialize() -> void:
	var failures: Array[String] = []
	var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_resources.json"))
	if typeof(config) != TYPE_DICTIONARY:
		push_error("V081_POKEMON_ART_VALIDATION_FAIL: invalid art_resources.json")
		quit(1)
		return
	for actor_id in EXISTING_THREE_KINGDOMS_IDS:
		if not config.get("portraits", {}).has(actor_id) or not config.get("units", {}).has(actor_id):
			failures.append("existing Three Kingdoms mapping was lost: " + actor_id)
	ArtCatalogScript.reload()
	for actor_id in POKEMON_IDS:
		_validate_asset(config, actor_id, "portraits", Vector2i(640, 960), failures)
		_validate_asset(config, actor_id, "units", Vector2i(512, 512), failures)
		var layout = config.get("units_layouts", {}).get(actor_id, {})
		if typeof(layout) != TYPE_DICTIONARY or layout.is_empty():
			failures.append("missing unit layout: " + actor_id)
		elif layout.get("anchor", []).size() != 2 or float(layout.anchor[1]) < 0.80 or float(layout.anchor[1]) > 0.95:
			failures.append("unsafe foot anchor: " + actor_id)
	if failures.is_empty():
		print("V081_POKEMON_ART_VALIDATION_PASS portraits=10 units=10 alpha=true resources=true mappings_preserved=true")
		quit(0)
		return
	for failure in failures:
		push_error("V081_POKEMON_ART_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_asset(config: Dictionary, actor_id: String, group: String, expected_size: Vector2i, failures: Array[String]) -> void:
	var path := str(config.get(group, {}).get(actor_id, ""))
	if path.is_empty() or not FileAccess.file_exists(path):
		failures.append("missing %s path: %s" % [group, actor_id])
		return
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK or image.is_empty():
		failures.append("unreadable %s: %s" % [group, actor_id])
		return
	if image.get_size() != expected_size:
		failures.append("wrong %s size for %s: %s" % [group, actor_id, image.get_size()])
	if image.detect_alpha() == Image.ALPHA_NONE:
		failures.append("missing alpha channel: %s/%s" % [group, actor_id])
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0 or used.end.x >= image.get_width() or used.end.y >= image.get_height():
		failures.append("invalid transparent margin: %s/%s" % [group, actor_id])
	var texture: Texture2D = ArtCatalogScript.texture(group, actor_id)
	if texture == null:
		failures.append("ArtCatalog failed: %s/%s" % [group, actor_id])
