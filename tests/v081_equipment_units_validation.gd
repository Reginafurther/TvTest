extends SceneTree

const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const InventoryUIScript = preload("res://scripts/inventory_ui.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const ACTORS := ["zhao_yun", "liu_bei", "zhang_fei", "guan_yu", "lu_bu", "zhuge_liang", "huang_zhong", "dian_wei", "diao_chan", "zhou_yu"]

var equipment_config: Dictionary

func _initialize() -> void:
	var failures: Array[String] = []
	equipment_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	if equipment_config.is_empty():
		push_error("V081_EQUIPMENT_UNITS_VALIDATION_FAIL: equipment config missing")
		quit(1)
		return
	_test_filter_and_cross_actor_guard(failures)
	_test_ring_cases(failures)
	_test_unit_resources(failures)
	if failures.is_empty():
		print("V081_EQUIPMENT_UNITS_VALIDATION_PASS filter=true cross_actor_guard=true rings=A-F persistence=true units=10")
		quit(0)
		return
	for failure in failures:
		push_error("V081_EQUIPMENT_UNITS_VALIDATION_FAIL: " + failure)
	quit(1)

func _manager() -> Node:
	var manager = InventoryManagerScript.new()
	manager.setup(equipment_config)
	return manager

func _ring(id: String, score: float, locked: bool = false) -> Dictionary:
	return {
		"instance_id": id, "template_id":"test_ring", "name":id,
		"slot":"ring_1", "compatible_slots":["ring_1", "ring_2"],
		"quality":"purple", "quality_rank":3, "level":1,
		"base_stats":{"attack":score}, "affixes":[], "special_effects":[],
		"locked":locked
	}

func _test_filter_and_cross_actor_guard(failures: Array[String]) -> void:
	var manager = _manager()
	var free_ring := _ring("free", 2.0)
	var own_ring := _ring("own", 3.0)
	var other_ring := _ring("other", 99.0)
	for item in [free_ring, own_ring, other_ring]: manager.add_item(item, false)
	manager.equip_item("zhao_yun", "own", "ring_1", false)
	manager.equip_item("liu_bei", "other", "ring_1", false)
	var visible_ids: Array = manager.available_items_for_actor("zhao_yun").map(func(item): return str(item.instance_id))
	if visible_ids != ["free", "own"]: failures.append("actor filter did not hide another actor's equipped item")
	if manager.available_items_for_actor("zhao_yun", true).size() != 3: failures.append("show-all inventory did not expose annotated management view")
	var before_zhao: Dictionary = manager.equipped.zhao_yun.duplicate(true)
	var before_liu: Dictionary = manager.equipped.liu_bei.duplicate(true)
	if manager.equip_item("zhao_yun", "other", "ring_2", false): failures.append("direct equip stole another actor's item")
	if manager.equipped.zhao_yun != before_zhao or manager.equipped.liu_bei != before_liu: failures.append("failed cross-actor equip mutated equipment state")
	var plan := [{"instance_id":"other", "slot":"ring_2", "gain":999.0, "combat_role":""}]
	if manager.apply_optimization("zhao_yun", plan) != 0 or manager.equipped.zhao_yun != before_zhao or manager.equipped.liu_bei != before_liu: failures.append("optimization bypassed cross-actor ownership guard")
	manager.equipped.liu_bei.ring_2 = "own"
	manager.remove_broken_references()
	if not manager.equipped_instances_unique(): failures.append("legacy duplicate equipped reference was not repaired on load")
	manager.free()

func _test_ring_cases(failures: Array[String]) -> void:
	# A: two legal rings and no upgrade remain stable through ten attempts.
	var stable = _manager()
	stable.add_item(_ring("A", 10.0), false); stable.add_item(_ring("B", 8.0), false)
	stable.equip_item("zhao_yun", "A", "ring_1", false); stable.equip_item("zhao_yun", "B", "ring_2", false)
	for _attempt in range(10):
		var choices: Array = stable.optimize_candidates("zhao_yun", 0, 9)
		if not choices.is_empty(): stable.apply_optimization("zhao_yun", choices)
	if stable.equipped.zhao_yun.ring_1 != "A" or stable.equipped.zhao_yun.ring_2 != "B": failures.append("case A changed or dropped stable ring pair")
	stable.free()

	# B/E: one better ring replaces only the weaker ring and survives reload.
	var upgrade = _manager()
	upgrade.save_path = "user://v081_ring_pair_test.json"
	for item in [_ring("A", 10.0), _ring("B", 8.0), _ring("C", 12.0)]: upgrade.add_item(item, false)
	upgrade.equip_item("zhao_yun", "A", "ring_1", false); upgrade.equip_item("zhao_yun", "B", "ring_2", false)
	var upgrade_plan: Array = upgrade.optimize_candidates("zhao_yun", 0, 9)
	if upgrade.apply_optimization("zhao_yun", upgrade_plan) != 1 or upgrade.equipped.zhao_yun.ring_1 != "A" or upgrade.equipped.zhao_yun.ring_2 != "C": failures.append("case B did not replace only the weaker ring")
	var loaded = _manager(); loaded.save_path = upgrade.save_path
	if not loaded.load_from_disk() or loaded.equipped.zhao_yun.ring_1 != "A" or loaded.equipped.zhao_yun.ring_2 != "C": failures.append("case E ring pair did not persist")
	upgrade.free(); loaded.free()

	# C: a single equipped ring plus an available ring fills the empty slot.
	var fill = _manager()
	fill.add_item(_ring("A", 10.0), false); fill.add_item(_ring("B", 2.0), false)
	fill.equip_item("zhao_yun", "A", "ring_1", false)
	var fill_plan: Array = fill.optimize_candidates("zhao_yun", 0, 9)
	if fill.apply_optimization("zhao_yun", fill_plan) != 1 or fill.equipped.zhao_yun.ring_1 != "A" or fill.equipped.zhao_yun.ring_2 != "B": failures.append("case C did not fill empty second ring slot")
	fill.free()

	# D/F: other actors' rings are unavailable and a locked ring remains in place.
	var protected = _manager()
	for item in [_ring("LOCKED", 1.0, true), _ring("OWN", 3.0), _ring("OTHER", 100.0), _ring("BETTER", 9.0)]: protected.add_item(item, false)
	protected.equip_item("zhao_yun", "LOCKED", "ring_1", false); protected.equip_item("zhao_yun", "OWN", "ring_2", false); protected.equip_item("liu_bei", "OTHER", "ring_1", false)
	var protected_plan: Array = protected.optimize_candidates("zhao_yun", 0, 9)
	protected.apply_optimization("zhao_yun", protected_plan)
	if protected.equipped.zhao_yun.ring_1 != "LOCKED": failures.append("case F moved a locked ring")
	if protected.equipped.zhao_yun.ring_2 != "BETTER": failures.append("case D/F failed to use the best legal ring")
	if protected.equipped.liu_bei.ring_1 != "OTHER": failures.append("case D stole another actor's high-score ring")
	if not protected.all_ids_unique() or not protected.equipped_instances_unique(): failures.append("inventory or equipped instance IDs are not unique")
	protected.free()

func _test_unit_resources(failures: Array[String]) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/art_resources.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		failures.append("art_resources.json is invalid")
		return
	var units: Dictionary = parsed.get("units", {})
	var layouts: Dictionary = parsed.get("units_layouts", {})
	ArtCatalogScript.reload()
	for actor_id in ACTORS:
		var path := str(units.get(actor_id, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			failures.append("missing unit image for " + actor_id)
			continue
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(path)) != OK or image.is_empty() or image.get_width() != image.get_height() or image.detect_alpha() == Image.ALPHA_NONE:
			failures.append("invalid transparent square unit image for " + actor_id)
		if not layouts.has(actor_id): failures.append("missing unit layout for " + actor_id)
		var texture: Texture2D = ArtCatalogScript.texture("units", actor_id)
		if texture == null:
			failures.append("ArtCatalog failed to load unit " + actor_id)
		elif actor_id != "zhao_yun" and (texture.get_width() > 512 or texture.get_height() > 512):
			failures.append("unit import size limit was not applied for " + actor_id)
