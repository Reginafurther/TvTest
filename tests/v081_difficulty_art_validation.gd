extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")

const THREE_KINGDOMS_ACTORS := [
	"zhao_yun", "liu_bei", "zhang_fei", "guan_yu", "lu_bu",
	"zhuge_liang", "huang_zhong", "dian_wei", "diao_chan", "zhou_yu"
]

func _initialize() -> void:
	var failures: Array[String] = []
	_validate_difficulty(failures)
	_validate_migration(failures)
	_validate_portraits(failures)
	if failures.is_empty():
		print("V081_DIFFICULTY_ART_VALIDATION_PASS formula=true migration_once=true portraits=10")
		quit(0)
		return
	for failure in failures:
		push_error("V081_DIFFICULTY_ART_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_difficulty(failures: Array[String]) -> void:
	var controller = BattleControllerScript.new()
	var equivalents := {1.0: 13.2, 1.5: 19.8, 2.0: 26.4, 3.0: 39.6, 4.0: 52.8, 5.0: 66.0, 6.0: 79.2, 7.0: 92.4, 8.0: 105.6}
	for new_coefficient in equivalents:
		var legacy: float = equivalents[new_coefficient]
		var profile: Dictionary = controller.custom_difficulty_profile(float(new_coefficient))
		if not is_equal_approx(float(profile.equivalent_old_coefficient), legacy):
			failures.append("difficulty %.1f equivalent mismatch" % new_coefficient)
		if not is_equal_approx(float(profile.health), pow(legacy, 0.55)) \
			or not is_equal_approx(float(profile.attack), pow(legacy, 0.35)) \
			or not is_equal_approx(float(profile.defense), pow(legacy, 0.18)):
			failures.append("difficulty %.1f formula mismatch" % new_coefficient)
	controller.free()

func _validate_migration(failures: Array[String]) -> void:
	var migrated = ProgressionManagerScript.new()
	if not migrated.apply_payload({"version":"1.0", "team_progression_version":1, "combat_difficulty":3.0, "difficulty_config_version":3, "transaction_log":[]}):
		failures.append("legacy payload rejected")
	if not is_equal_approx(migrated.combat_difficulty, 1.0):
		failures.append("v3 difficulty 3.0 did not migrate to v4 1.0")
	if migrated.difficulty_config_version != ProgressionManagerScript.DIFFICULTY_CONFIG_VERSION:
		failures.append("difficulty config version not advanced")
	var migration_count: int = migrated.transaction_log.size()
	var reloaded = ProgressionManagerScript.new()
	reloaded.apply_payload({
		"version":"0.8",
		"team_progression_version":1,
		"combat_difficulty":migrated.combat_difficulty,
		"difficulty_config_version":migrated.difficulty_config_version,
		"difficulty_migration_record":migrated.difficulty_migration_record,
		"transaction_log":migrated.transaction_log
	})
	if reloaded.transaction_log.size() != migration_count:
		failures.append("difficulty migration repeated")
	var low = ProgressionManagerScript.new()
	low.apply_payload({"version":"1.0", "team_progression_version":1, "combat_difficulty":1.0, "difficulty_config_version":3, "transaction_log":[]})
	if not is_equal_approx(low.combat_difficulty, 1.0) or not bool(low.difficulty_migration_record.get("clamped", false)):
		failures.append("legacy value below new range was not explicitly clamped to 1.0")
	migrated.free()
	reloaded.free()
	low.free()

func _validate_portraits(failures: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_resources.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("art_resources.json is invalid")
		return
	var portraits: Dictionary = parsed.get("portraits", {})
	for actor_id in THREE_KINGDOMS_ACTORS:
		var path := str(portraits.get(actor_id, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			failures.append("missing portrait path for " + actor_id)
			continue
		var image := Image.new()
		var load_error := image.load(ProjectSettings.globalize_path(path))
		if load_error != OK or image.is_empty() or image.get_width() != 1024 or image.get_height() != 1536:
			failures.append("unreadable or wrong-size portrait for " + actor_id)
		elif image.detect_alpha() == Image.ALPHA_NONE:
			failures.append("portrait lacks transparency for " + actor_id)
	ArtCatalogScript.reload()
	for actor_id in THREE_KINGDOMS_ACTORS:
		if ArtCatalogScript.portrait(actor_id) == null:
			failures.append("ArtCatalog failed to load " + actor_id)
