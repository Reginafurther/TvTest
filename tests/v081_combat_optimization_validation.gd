extends SceneTree

const BattleUnitScript = preload("res://scripts/unit.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")

const EXPECTED_ACTOR_TYPES := {
	"zhao_yun":"physical", "liu_bei":"none", "zhang_fei":"physical", "dian_wei":"physical", "zhuge_liang":"elemental", "lu_bu":"physical", "guan_yu":"physical", "huang_zhong":"physical", "diao_chan":"elemental", "zhou_yu":"elemental",
	"pikachu":"elemental", "snorlax":"physical", "gengar":"elemental", "mewtwo":"elemental", "bulbasaur":"elemental", "charmander":"elemental", "squirtle":"physical", "lucario":"elemental", "gardevoir":"elemental", "dragonite":"physical",
	"chen_motong":"physical", "chu_zihang":"physical", "yabuki_sakura":"physical", "lu_mingfei":"none", "lu_mingze":"elemental", "caesar":"physical", "eri_uesugi":"elemental", "minamoto_chisei":"physical", "minamoto_chime":"elemental", "zero":"physical",
	"blood_river":"physical", "iron_guard":"physical", "broken_dream":"physical", "divine_harmony":"elemental", "plain_question":"none", "nine_spirits":"elemental"
}

class FakeBattle extends Node:
	var heroes: Array = []
	var enemies: Array = []
	var general_skills_config: Dictionary = {}
	var suppress_combat_visuals := true
	var is_paused := true
	var active_rift_context: Dictionary = {}
	var last_heal := 0.0
	func record_damage_resolution(_source, _target, _result: Dictionary, _context: Dictionary) -> void: pass
	func on_damage(_source, _target, _amount: float, _context: Dictionary) -> void: pass
	func on_heal(_source, amount: float) -> void: last_heal = amount
	func note_passive(_actor_id: String, _passive_id: String) -> void: pass
	func find_closest_enemy(seeker):
		var pool: Array = enemies if seeker.faction == "heroes" else heroes
		var best
		var distance := INF
		for candidate in pool:
			if is_instance_valid(candidate) and not candidate.dead:
				var current: float = seeker.position.distance_squared_to(candidate.position)
				if current < distance: distance = current; best = candidate
		return best

func _initialize() -> void:
	var failures: Array[String] = []
	_validate_damage_type_data(failures)
	_validate_equipment_config_and_migration(failures)
	_validate_damage_formula(failures)
	_validate_healing_formula(failures)
	_validate_stage_29_unlock(failures)
	_validate_healer_anchor(failures)
	if failures.is_empty():
		print("V081_COMBAT_OPTIMIZATION_VALIDATION_PASS actors=36 exclusive=36 general_active=44 damage=true healing=true affix_migration=true stage30=true healer_anchor=true")
		quit(0)
		return
	for failure in failures: push_error("V081_COMBAT_OPTIMIZATION_VALIDATION_FAIL: " + failure)
	quit(1)

func _merged_data(base_path: String, section: String) -> Dictionary:
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base_path))
	var v08: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/v08_content.json"))
	result.merge(v08.get(section, {}), true)
	return result

func _validate_damage_type_data(failures: Array[String]) -> void:
	var actors := _merged_data("res://data/actors.json", "actors")
	var skills := _merged_data("res://data/skills.json", "skills")
	var general := _merged_data("res://data/general_skills.json", "general_skills")
	for actor_id in EXPECTED_ACTOR_TYPES:
		if str(actors.get(actor_id, {}).get("basic_damage_type", "")) != EXPECTED_ACTOR_TYPES[actor_id]: failures.append("wrong basic damage type: " + actor_id)
	for healer_id in ["liu_bei", "lu_mingfei", "plain_question"]:
		var healer: Dictionary = actors.get(healer_id, {})
		if str(healer.get("combat_role", "")) != "healer" or str(healer.get("basic_action", "")) != "heal" or str(healer.get("basic_damage_type", "")) != "none": failures.append("healer basic configuration is inconsistent: " + healer_id)
	var hero_skills: Array[String] = []
	for actor_id in EXPECTED_ACTOR_TYPES: hero_skills.append(str(actors[actor_id].skill))
	if hero_skills.size() != 36 or hero_skills.duplicate().size() != 36: failures.append("hero exclusive skill roster is not 36")
	for skill_id in hero_skills:
		if str(skills.get(skill_id, {}).get("damage_type", "")) not in ["physical", "elemental", "none"]: failures.append("missing exclusive damage type: " + skill_id)
	var active_count := 0
	for skill_id in general:
		if str(general[skill_id].get("category", "")) != "active": continue
		active_count += 1
		if str(general[skill_id].get("damage_type", "")) not in ["physical", "elemental", "none"]: failures.append("missing general damage type: " + skill_id)
	if active_count != 44: failures.append("general active skill count is %d, expected 44" % active_count)

func _validate_equipment_config_and_migration(failures: Array[String]) -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	if config.affixes.has("life_regen"): failures.append("new affix pool still contains life_regen")
	for stat_id in ["final_damage", "damage_reduction", "healing_effect"]:
		if not config.affixes.has(stat_id): failures.append("missing equipment affix " + stat_id)
	var inventory = InventoryManagerScript.new(); inventory.setup(config)
	inventory.items = [{"instance_id":"legacy", "base_stats":{}, "affixes":[{"stat":"life_regen", "value":2.0}], "locked":true}]
	if not inventory.migrate_legacy_life_regen_affixes(): failures.append("legacy affix migration reported no change")
	var migrated: Dictionary = inventory.items[0].affixes[0]
	if str(migrated.stat) != "healing_effect" or not is_equal_approx(float(migrated.value), 0.04): failures.append("legacy flat regen 2 was not safely converted to 4% healing")
	if not bool(inventory.items[0].locked) or str(inventory.items[0].instance_id) != "legacy": failures.append("affix migration changed item identity or lock")
	inventory.free()
	var migration_path := "user://v081_affix_migration_test.json"
	var legacy_payload := {"version":"0.8", "items":[{"instance_id":"persisted", "base_stats":{}, "affixes":[{"stat":"life_regen", "value":2.0}], "locked":false}], "equipped":{}}
	var file := FileAccess.open(migration_path, FileAccess.WRITE); file.store_string(JSON.stringify(legacy_payload)); file.close()
	var loaded = InventoryManagerScript.new(); loaded.setup(config); loaded.save_path = migration_path
	if not loaded.load_from_disk() or not is_equal_approx(float(loaded.items[0].affixes[0].value), 0.04): failures.append("legacy affix did not migrate through load")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(migration_path))
	if int(saved.get("affix_config_version", 0)) != InventoryManagerScript.AFFIX_CONFIG_VERSION: failures.append("affix migration version was not persisted")
	var reloaded = InventoryManagerScript.new(); reloaded.setup(config); reloaded.save_path = migration_path; reloaded.load_from_disk()
	if not is_equal_approx(float(reloaded.items[0].affixes[0].value), 0.04): failures.append("affix migration repeated on reload")
	if FileAccess.file_exists(migration_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	loaded.free(); reloaded.free()

func _unit(battle: FakeBattle, faction: String, position_value: Vector2) -> Node:
	var unit = BattleUnitScript.new(); unit.battle = battle; unit.faction = faction; unit.position = position_value; unit.actor_data = {}; unit.max_hp = 10000.0; unit.hp = unit.max_hp; unit.defense = 0.0
	root.add_child(unit)
	return unit

func _validate_damage_formula(failures: Array[String]) -> void:
	var battle := FakeBattle.new(); root.add_child(battle)
	var source = _unit(battle, "heroes", Vector2.ZERO); var target = _unit(battle, "enemies", Vector2(100, 0))
	source.physical_damage = 0.20; source.elemental_damage = 0.30; source.final_damage = 0.10
	target.defense = 100.0; target.damage_reduction = 0.10; target.temporary_reduction = 0.06; target.temporary_reduction_time = 1.0
	var result: Dictionary = target.take_damage(1000.0, source, false, {"kind":"basic", "damage_type":"physical", "allow_triggers":false})
	# (1000*1.20 - 100*0.55) * 1.10 * 0.90 * 0.94 = 1065.537 -> 1066
	if int(result.hp_damage) != 1066: failures.append("independent final damage/reduction formula produced %d" % int(result.hp_damage))
	if not is_equal_approx(float(result.reduction), 0.154): failures.append("equipment and skill reduction did not multiply independently")
	target.hp = target.max_hp; target.defense = 0.0; target.damage_reduction = 0.0; target.temporary_reduction_time = 0.0
	var elemental: Dictionary = target.take_damage(100.0, source, false, {"kind":"effect", "damage_type":"elemental", "burn":true, "allow_triggers":false})
	if int(elemental.hp_damage) != 143: failures.append("elemental DOT did not apply elemental/final bonus exactly once")
	source.queue_free(); target.queue_free(); battle.queue_free()

func _validate_healing_formula(failures: Array[String]) -> void:
	var battle := FakeBattle.new(); root.add_child(battle)
	var healer = _unit(battle, "heroes", Vector2.ZERO); healer.healing_effect = 0.20
	if not is_equal_approx(healer.basic_heal_amount(100.0 * BattleUnitScript.HEALER_BASIC_ATTACK_RATIO), 48.0): failures.append("healer basic attack is not 40% with healing effect")
	if not is_equal_approx(healer.active_heal_amount(100.0), 180.0): failures.append("player active heal is not exactly 1.5x with healing effect")
	healer.faction = "enemies"
	if not is_equal_approx(healer.active_heal_amount(100.0), 120.0): failures.append("monster healing incorrectly received player 1.5x multiplier")
	healer.queue_free(); battle.queue_free()

func _validate_stage_29_unlock(failures: Array[String]) -> void:
	var path := "user://v081_stage29_progress_test.json"
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var progression = ProgressionManagerScript.new(); progression.save_path = path; progression.progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json")); progression.completed_stages = range(1, 29); progression.ensure_world_layout()
	if not progression.complete_stage(29) or not progression.is_stage_complete(29) or not progression.can_enter_stage(30): failures.append("completing stage 29 did not unlock stage 30")
	var loaded = ProgressionManagerScript.new(); loaded.save_path = path; loaded.progression_config = progression.progression_config
	if not loaded.load_from_disk() or not loaded.can_enter_stage(30): failures.append("stage 30 unlock did not persist")
	if loaded.complete_stage(29): failures.append("repeating stage 29 was treated as a first clear")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	progression.free(); loaded.free()

func _validate_healer_anchor(failures: Array[String]) -> void:
	var battle := FakeBattle.new(); root.add_child(battle)
	var healer = _unit(battle, "heroes", Vector2(200, 250)); healer.attack_range = 200.0; healer.actor_data = {"combat_role":"healer"}
	var tank = _unit(battle, "heroes", Vector2(500, 250)); tank.actor_data = {"combat_role":"tank", "combat_style":"tank"}
	var melee = _unit(battle, "heroes", Vector2(430, 300)); melee.actor_data = {"combat_role":"melee_dps", "combat_style":"melee"}
	var enemy = _unit(battle, "enemies", Vector2(760, 250))
	battle.heroes = [healer, tank, melee]; battle.enemies = [enemy]
	if healer.healer_anchor() != tank: failures.append("healer did not choose the living front-line tank")
	var point: Vector2 = healer.healer_follow_point(tank, enemy)
	if absf(point.distance_to(tank.position) - 150.0) > 0.1 or point.x >= tank.position.x: failures.append("healer follow point is not 75% range behind the tank")
	tank.dead = true
	if healer.healer_anchor() != melee: failures.append("healer did not fall back to a living melee anchor")
	for unit in [healer, tank, melee, enemy]: unit.queue_free()
	battle.queue_free()
