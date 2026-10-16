class_name BattleController
extends Node2D

const DataLoaderScript = preload("res://scripts/data_loader.gd")
const BattleMapScript = preload("res://scripts/battle_map.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const EffectRingScript = preload("res://scripts/effect_ring.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const EquipmentGeneratorScript = preload("res://scripts/equipment_generator.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const CombatStatsScript = preload("res://scripts/combat_stats.gd")
const CraftingManagerScript = preload("res://scripts/crafting_manager.gd")
const ShopManagerScript = preload("res://scripts/shop_manager.gd")
const AdventureManagerScript = preload("res://scripts/adventure_manager.gd")
const ResetManagerScript = preload("res://scripts/reset_manager.gd")
const WORLD_ENEMY_HEALTH_MULTIPLIER := 0.80
const WORLD_ENEMY_DEFENSE_MULTIPLIER := 0.80

signal stats_changed(kills: int, elapsed: float, wave: int)
signal party_changed(party: Array)
signal log_message(message: String)
signal battle_state_changed(message: String)
signal loot_obtained(item: Dictionary)
signal world_changed(map_id: String)
signal progression_changed

var actors: Dictionary
var skills: Dictionary
var equipment_config: Dictionary
var loot_config: Dictionary
var worlds_config: Dictionary
var shop_config: Dictionary
var passives_config: Dictionary
var general_skills_config: Dictionary
var inventory
var equipment_generator
var progression
var crafting
var shop
var adventure
var combat_stats
var battle_map: Node2D
var astar := AStarGrid2D.new()
var heroes: Array = []
var enemies: Array = []
var elapsed := 0.0
var kills := 0
var wave := 1
var spawn_timer := 0.0
var is_paused := false
var game_over := false
var obstacle_cells: Dictionary = {}
var loot_test_mode := false
var current_map_id := "hulao_pass"
var active_boss_id := ""
var passive_trigger_counts: Dictionary = {}
var stage_cleared := false
var stage_boss_active := false
var stage_boss_spawned := false
var stage_boss_defeated := false
var stage_resolution_started := false
var ai_trace: Array = []
var ai_trace_timer := 0.0
var ai_test_wave := 0
var stage_transition_timer := -1.0
var damage_trace: Array = []
var zero_damage_streaks: Dictionary = {}
var damage_anomalies: Array = []
var suppress_combat_visuals := false
var party_hud_dirty := false
var party_hud_timer := 0.0
var active_rift_context: Dictionary = {}
var combat_log: Array[String] = []
var retry_timer := -1.0
var consecutive_defeats := 0
var auto_retry_enabled := true
var reset_manager

func _ready() -> void:
	actors = DataLoaderScript.load_json("res://data/actors.json")
	skills = DataLoaderScript.load_json("res://data/skills.json")
	equipment_config = DataLoaderScript.load_json("res://data/equipment.json")
	loot_config = DataLoaderScript.load_json("res://data/loot_tables.json")
	worlds_config = DataLoaderScript.load_json("res://data/worlds.json")
	shop_config = DataLoaderScript.load_json("res://data/shop.json")
	passives_config = DataLoaderScript.load_json("res://data/passives.json")
	general_skills_config = DataLoaderScript.load_json("res://data/general_skills.json")
	for content_path in ["res://data/v08_content.json", "res://data/v09_wow_content.json", "res://data/v09_jinyong_content.json", "res://data/v10_qin_content.json", "res://data/v10_naruto_content.json", "res://data/v11_huangyi_content.json", "res://data/v12_fengyun_content.json"]:
		var content: Dictionary = DataLoaderScript.load_json(content_path)
		actors.merge(content.get("actors", {}), true)
		skills.merge(content.get("skills", {}), true)
		passives_config.merge(content.get("passives", {}), true)
		general_skills_config.merge(content.get("general_skills", {}), true)
		worlds_config.maps.merge(content.get("maps", {}), true)
		worlds_config.bosses.merge(content.get("bosses", {}), true)
		worlds_config.recruitment.costs.merge(content.get("recruitment", {}), true)
	apply_playable_melee_survival_baseline()
	apply_playable_attack_interval_baseline()
	for skill_id in general_skills_config:
		if not general_skills_config[skill_id].has("function_type"):
			general_skills_config[skill_id].function_type = infer_skill_function(str(general_skills_config[skill_id].get("effect", "")))
	log_message.connect(_store_combat_log)
	loot_test_mode = "--loot-test" in OS.get_cmdline_user_args() or "--equipment-test" in OS.get_cmdline_user_args() or "--v03-test" in OS.get_cmdline_user_args() or "--v031-test" in OS.get_cmdline_user_args()
	inventory = InventoryManagerScript.new()
	inventory.setup(equipment_config, actors)
	add_child(inventory)
	var args := OS.get_cmdline_user_args()
	var v061_write_test := false
	for value in args:
		if (str(value).begins_with("--v061-") or str(value).begins_with("--v07-") or str(value).begins_with("--v08-") or str(value).begins_with("--v081-") or str(value).begins_with("--v09-") or str(value).begins_with("--v10-")) and str(value) not in ["--v061-persist-read", "--v07-persist-read", "--v08-persist-read", "--v081-reset-read"]: v061_write_test = true
	if "--equipment-test" in args or "--persistence-write" in args or "--v03-test" in args or "--v031-test" in args or "--v05-test" in args or "--v05-core-test" in args or "--v05-shop-test" in args or "--v05-skill-test" in args or "--v05-system-test" in args or v061_write_test:
		inventory.clear_test_save()
	inventory.load_from_disk()
	inventory.equipment_changed.connect(_on_equipment_changed)
	progression = ProgressionManagerScript.new()
	progression.setup()
	add_child(progression)
	for boss_id in worlds_config.bosses:
		if not progression.boss_first_clear.has(boss_id): progression.boss_first_clear[boss_id] = false
	progression.changed.connect(func(): progression_changed.emit())
	reset_manager = ResetManagerScript.new()
	if worlds_config.maps.has(progression.last_stage_id):
		var saved_stage := int(worlds_config.maps[progression.last_stage_id].get("global_stage", 1))
		if progression.can_enter_stage(saved_stage):
			current_map_id = progression.last_stage_id
	equipment_generator = EquipmentGeneratorScript.new(equipment_config, loot_config, 20261012 if loot_test_mode else 0)
	crafting = CraftingManagerScript.new()
	crafting.setup(inventory, progression, equipment_config, equipment_generator)
	shop = ShopManagerScript.new()
	shop.setup(inventory, progression, equipment_generator, shop_config)
	adventure = AdventureManagerScript.new()
	add_child(adventure)
	adventure.setup(self)
	adventure.encounter_notice.connect(func(message): log_message.emit("★ " + message))
	combat_stats = CombatStatsScript.new()
	combat_stats.reset()
	battle_map = BattleMapScript.new()
	battle_map.map_id = current_map_id
	add_child(battle_map)
	setup_navigation()
	spawn_party()
	if has_damage_dealer_in_party():
		spawn_wave()
	else:
		battle_state_changed.emit("等待招募并上阵输出角色")
		log_message.emit("新冒险团只有刘备，请先用虎符招募并上阵至少一名输出角色。")

func setup_navigation() -> void:
	astar.region = Rect2i(0, 0, 34, 17)
	astar.cell_size = Vector2(32, 32)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update()

func spawn_party() -> void:
	var ids: Array = progression.party
	for i in range(ids.size()):
		if str(ids[i]).is_empty():
			continue
		var pos := formation_point(str(ids[i]), i)
		spawn_unit(ids[i], "heroes", pos)
	party_changed.emit(heroes)

func spawn_wave() -> void:
	if game_over or stage_cleared or stage_resolution_started:
		return
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var target_wave := int(map_data.get("waves_to_clear", 3))
	# `wave` is the next wave to spawn. Never allow an invalid (for example 4/3)
	# wave to become a recovery path after the stage boss has already appeared.
	if wave > target_wave:
		if enemies.is_empty():
			resolve_stage_wave()
		return
	# A wave boundary is authoritative for taunt readiness and front-line staging.
	# The unit decides which equipped skills are taunts, so other cooldowns remain intact.
	for hero in heroes:
		if is_instance_valid(hero) and not hero.dead and not hero.is_summon:
			hero.begin_combat_wave()
	if not str(map_data.get("main_boss", "")).is_empty() and wave == target_wave:
		stage_boss_active = true
		stage_boss_spawned = true
		stage_boss_defeated = false
		var stage := int(map_data.get("global_stage", 1))
		var overrides: Dictionary = {"enemy_type":"boss", "stage_boss":true, "boss_id":"stage_%d" % stage, "boss_mechanic":map_data.get("boss_mechanic", ""), "world":map_data.get("world", "")}
		if map_data.has("boss_name"):
			overrides.merge({"name":map_data.boss_name, "skill":map_data.get("boss_skill", "enemy_strike")}, true)
		var boss = spawn_unit(str(map_data.main_boss), "enemies", Vector2(875, 260), overrides)
		boss.enemy_type = "boss"
		boss.monster_level = stage
		if str(map_data.main_boss).begins_with("stage_guardian") or stage > 40:
			boss.max_hp *= difficulty_multiplier("guardian_health", stage)
			boss.hp = boss.max_hp
			boss.attack *= difficulty_multiplier("guardian_attack", stage)
			boss.defense *= difficulty_multiplier("guardian_defense", stage)
		else:
			var final_scale: Dictionary = progression.progression_config.get("combat_difficulty", {}).get("final_boss", {}).get(str(stage), {})
			boss.max_hp *= float(final_scale.get("health", 1.0))
			boss.hp = boss.max_hp
			boss.attack *= float(final_scale.get("attack", 1.0))
			boss.defense *= float(final_scale.get("defense", 1.0))
		log_message.emit("主线第 %d 关关底Boss登场：【%s】" % [stage, boss._name()])
		wave += 1
		return
	var pool := valid_mainline_enemy_pool(map_data)
	if pool.is_empty():
		push_error("主线关卡%s没有有效普通怪配置，已停止生成该波。" % current_map_id)
		return
	var count := mini(3 + wave, 9)
	for i in range(count):
		var id: String = pool[(i + wave) % pool.size()]
		var pos := Vector2(900 + randf_range(-50, 70), 70 + i * (380.0 / maxf(1, count - 1)) + randf_range(-18, 18))
		var enemy = spawn_unit(id, "enemies", pos)
		var difficulty := int(map_data.get("difficulty_level", map_data.get("level", 1)))
		enemy.monster_level = difficulty
		enemy.max_hp *= difficulty_multiplier("regular_health", difficulty)
		enemy.attack *= difficulty_multiplier("regular_attack", difficulty)
		enemy.defense *= difficulty_multiplier("regular_defense", difficulty)
		if wave >= 2 and i == count - 1:
			enemy.enemy_type = "elite"
			enemy.max_hp *= 1.75
			enemy.attack *= 1.35
		# Gentle wave scaling keeps the idle loop meaningful.
		enemy.max_hp *= 1.0 + (wave - 1) * 0.12
		enemy.hp = enemy.max_hp
		enemy.attack *= 1.0 + (wave - 1) * 0.07
	log_message.emit("第 %d 波敌人进入%s" % [wave, map_data.get("name", "地图")])
	wave += 1

func valid_mainline_enemy_pool(map_data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_id in map_data.get("enemy_pool", []):
		var enemy_id := str(raw_id)
		var data: Dictionary = actors.get(enemy_id, {})
		var enemy_type := str(data.get("enemy_type", "normal"))
		if not data.is_empty() and enemy_type in ["normal", "elite"] and not data.has("boss_id"):
			result.append(enemy_id)
	return result

func current_stage_wave() -> int:
	var total := maxi(1, int(worlds_config.maps.get(current_map_id, {}).get("waves_to_clear", 3)))
	return clampi(wave - 1, 1, total)

func difficulty_multiplier(curve_id: String, stage: int) -> float:
	var curve: Dictionary = progression.progression_config.get("combat_difficulty", {}).get(curve_id, {})
	var step := maxf(0.0, float(stage - 1))
	var linear := float(curve.get("linear", 0.0))
	var quadratic := float(curve.get("quadratic", 0.0))
	if stage <= 40:
		return 1.0 + step * linear + step * step * quadratic
	var stage_40_step := 39.0
	var stage_40_value := 1.0 + stage_40_step * linear + stage_40_step * stage_40_step * quadratic
	var stage_40_slope := linear + 2.0 * stage_40_step * quadratic
	return stage_40_value + float(stage - 40) * stage_40_slope * 0.60

func custom_difficulty_profile(value: float = -1.0) -> Dictionary:
	var coefficient: float = clampf(progression.combat_difficulty, 0.2, 3.0) if value < 0.0 else snappedf(clampf(value, 0.2, 3.0), 0.1)
	var equivalent_old_coefficient := 4.4 * coefficient
	return {
		"coefficient": coefficient,
		"equivalent_old_coefficient": equivalent_old_coefficient,
		"health": pow(equivalent_old_coefficient, 0.55),
		"attack": pow(equivalent_old_coefficient, 0.35),
		"defense": pow(equivalent_old_coefficient, 0.18),
		"world_health": pow(equivalent_old_coefficient, 0.55) * WORLD_ENEMY_HEALTH_MULTIPLIER,
		"world_defense": pow(equivalent_old_coefficient, 0.18) * WORLD_ENEMY_DEFENSE_MULTIPLIER
	}

func apply_custom_difficulty(unit) -> void:
	if not is_instance_valid(unit) or unit.faction != "enemies" or unit.has_meta("custom_difficulty_applied"): return
	var profile := custom_difficulty_profile()
	unit.max_hp *= float(profile.health)
	unit.hp = unit.max_hp
	unit.attack *= float(profile.attack)
	unit.defense *= float(profile.defense)
	unit.set_meta("custom_difficulty_applied", true)
	unit.set_meta("custom_difficulty_coefficient", float(profile.coefficient))

func apply_world_enemy_adjustment(unit) -> void:
	if not is_instance_valid(unit) or unit.faction != "enemies" or unit.has_meta("world_stats_adjusted"): return
	# The active combat context, rather than a reused actor template, decides
	# whether the world-map adjustment applies. Rift bosses and summons stay exempt.
	if not active_rift_context.is_empty(): return
	unit.max_hp *= WORLD_ENEMY_HEALTH_MULTIPLIER
	unit.hp = unit.max_hp
	unit.defense *= WORLD_ENEMY_DEFENSE_MULTIPLIER
	unit.set_meta("world_stats_adjusted", true)

func spawn_unit(id: String, faction: String, pos: Vector2, overrides: Dictionary = {}):
	var unit = BattleUnitScript.new()
	var data: Dictionary = actors.get(id, {}).duplicate(true)
	data.merge(overrides, true)
	if faction == "heroes" and id in ProgressionManagerScript.ALL_HERO_IDS:
		var breakthrough_stats := breakthrough_base_stats(id)
		for stat in ["max_hp", "attack", "defense"]:
			data[stat] = float(breakthrough_stats.get(stat, data.get(stat, 0.0)))
	var skill: Dictionary = skills.get(data.get("skill", ""), {})
	if skill.is_empty() and faction == "enemies" and data.has("boss_id"):
		skill = {"name":data.get("name", "首领技能"), "type":"boss_area", "power":0.82, "cooldown":7.0, "range":230.0}
	unit.setup(id, data, skill, faction, self)
	if faction == "enemies":
		var v08_scales: Dictionary = progression.progression_config.get("combat_difficulty", {}).get("v08_applied_scales", {})
		unit.max_hp *= float(v08_scales.get("health", 1.0)); unit.hp = unit.max_hp
		unit.attack *= float(v08_scales.get("attack", 1.0))
		unit.defense *= float(v08_scales.get("defense", 1.0))
		unit.monster_level = int(worlds_config.maps.get(current_map_id, {}).get("difficulty_level", 1))
		unit.enemy_type = str(data.get("enemy_type", "normal"))
		apply_custom_difficulty(unit)
		apply_world_enemy_adjustment(unit)
	unit.position = pos
	unit.died.connect(_on_unit_died)
	unit.combat_event.connect(_on_combat_event)
	unit.health_changed.connect(_on_health_changed)
	add_child(unit)
	if faction == "heroes":
		heroes.append(unit)
		combat_stats.ensure_actor(id)
		unit.home_position = pos
		unit.apply_equipment_stats(inventory.get_actor_stats(id), equipment_config.get("rules", {}))
	else:
		enemies.append(unit)
	return unit

func world_tier_for_name(world_name: String) -> int:
	var first_stage := 999999
	for map_id in worlds_config.get("maps", {}):
		var map_data: Dictionary = worlds_config.maps[map_id]
		if str(map_data.get("world", "")) == world_name:
			first_stage = mini(first_stage, int(map_data.get("global_stage", 999999)))
	return 1 if first_stage == 999999 else maxi(1, (first_stage - 1) / 10 + 1)

func native_world_tier(actor_id: String) -> int:
	return world_tier_for_name(str(actors.get(actor_id, {}).get("world", "")))

func maximum_unlocked_world_tier() -> int:
	var configured_max := 1
	for actor_id in ProgressionManagerScript.ALL_HERO_IDS:
		configured_max = maxi(configured_max, native_world_tier(str(actor_id)))
	return mini(configured_max, 1 + progression.completed_stages.size() / 10)

func _breakthrough_role(data: Dictionary) -> String:
	var role := str(data.get("combat_role", ""))
	var style := str(data.get("combat_style", ""))
	if role == "tank" or style == "tank": return "tank"
	if role == "healer" or style == "healer" or str(data.get("basic_action", "")) == "heal": return "healer"
	if style == "melee":
		var text := str(data.get("role", ""))
		return "assassin" if "刺客" in text or "爆发" in text else "warrior"
	if role == "support" or "辅助" in str(data.get("role", "")) or "控制" in str(data.get("role", "")): return "support"
	return "ranged_dps"

func _tier_role_target(tier: int, role: String) -> Dictionary:
	var totals := {"max_hp":0.0,"attack":0.0,"defense":0.0}
	var count := 0
	for hero_id in ProgressionManagerScript.ALL_HERO_IDS:
		var candidate: Dictionary = actors.get(hero_id, {})
		if not candidate.is_empty() and native_world_tier(str(hero_id)) == tier and _breakthrough_role(candidate) == role:
			for stat in totals: totals[stat] += float(candidate.get(stat, 0.0))
			count += 1
	if count > 0:
		for stat in totals: totals[stat] = float(totals[stat]) / count
		return totals
	# Some worlds have no exact role peer. Use the nearest-world peer rather than
	# changing a character's class or applying an arbitrary global multiplier.
	for distance in range(1, 20):
		for fallback_tier in [tier - distance, tier + distance]:
			if fallback_tier < 1: continue
			var fallback := _tier_role_target_exact(fallback_tier, role)
			if not fallback.is_empty(): return fallback
	return {}

func _tier_role_target_exact(tier: int, role: String) -> Dictionary:
	var totals := {"max_hp":0.0,"attack":0.0,"defense":0.0}
	var count := 0
	for hero_id in ProgressionManagerScript.ALL_HERO_IDS:
		var candidate: Dictionary = actors.get(hero_id, {})
		if not candidate.is_empty() and native_world_tier(str(hero_id)) == tier and _breakthrough_role(candidate) == role:
			for stat in totals: totals[stat] += float(candidate.get(stat, 0.0))
			count += 1
	if count == 0: return {}
	for stat in totals: totals[stat] = float(totals[stat]) / count
	return totals

func _is_remote_breakthrough_actor(data: Dictionary) -> bool:
	if str(data.get("combat_role", "")) == "tank" or str(data.get("combat_style", "")) == "tank": return false
	var style := str(data.get("combat_style", ""))
	var role := str(data.get("combat_role", ""))
	return style in ["ranged", "healer"] or (style != "melee" and role in ["ranged_dps", "support", "healer"])

func breakthrough_tank_health_reference(tier: int) -> float:
	return float(_tier_role_target(tier, "tank").get("max_hp", 0.0))

func breakthrough_base_stats(actor_id: String, requested_tier: int = -1) -> Dictionary:
	var data: Dictionary = actors.get(actor_id, {})
	if data.is_empty(): return {}
	var native_tier: int = native_world_tier(actor_id)
	var tier: int = int(progression.breakthrough_tier(actor_id, native_tier)) if requested_tier < 0 else maxi(native_tier, requested_tier)
	var result := {"max_hp":float(data.get("max_hp", 1.0)),"attack":float(data.get("attack", 1.0)),"defense":float(data.get("defense", 0.0))}
	for target_tier in range(native_tier + 1, tier + 1):
		var target: Dictionary = _tier_role_target(target_tier, _breakthrough_role(data))
		for stat in ["attack", "defense"]: result[stat] = maxf(float(result[stat]), float(target.get(stat, result[stat])))
		var target_health := float(target.get("max_hp", result.max_hp))
		if _is_remote_breakthrough_actor(data):
			var tank_health := breakthrough_tank_health_reference(target_tier)
			if tank_health > 0.0: target_health = tank_health * 0.75
		result.max_hp = maxf(float(result.max_hp), target_health)
	return result

func breakthrough_preview(actor_id: String) -> Dictionary:
	var native_tier: int = native_world_tier(actor_id)
	var current: int = int(progression.breakthrough_tier(actor_id, native_tier))
	var maximum: int = maximum_unlocked_world_tier()
	return {"native_tier":native_tier,"current_tier":current,"next_tier":mini(maximum, current + 1),"maximum_tier":maximum,"current_stats":breakthrough_base_stats(actor_id, current),"next_stats":breakthrough_base_stats(actor_id, mini(maximum, current + 1)),"stones":int(progression.materials.get("breakthrough_stone", 0)),"can_breakthrough":current < maximum and int(progression.materials.get("breakthrough_stone", 0)) > 0}

func actor_display_name(actor_id: String) -> String:
	var original := str(actors.get(actor_id, {}).get("name", actor_id))
	if progression == null: return original
	var native_tier: int = native_world_tier(actor_id)
	var tier: int = int(progression.breakthrough_tier(actor_id, native_tier))
	return "凡%d·%s" % [tier, original] if tier > native_tier else original

func tank_scoring_context(actor_id: String) -> Dictionary:
	var base := breakthrough_base_stats(actor_id)
	var level: int = progression.actor_level(actor_id)
	return {
		"base_health": float(base.get("max_hp", 1.0)) * (1.0 + (level - 1) * 0.08),
		"boss_attack": current_stage_boss_attack()
	}

func current_stage_boss_attack() -> float:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and bool(enemy.actor_data.get("stage_boss", false)):
			return maxf(1.0, float(enemy.attack))
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var template_id := str(map_data.get("main_boss", ""))
	var template: Dictionary = actors.get(template_id, {})
	var value := float(template.get("attack", 1.0))
	var v08_scales: Dictionary = progression.progression_config.get("combat_difficulty", {}).get("v08_applied_scales", {})
	value *= float(v08_scales.get("attack", 1.0))
	value *= float(custom_difficulty_profile().attack)
	var stage := int(map_data.get("global_stage", 1))
	if template_id.begins_with("stage_guardian") or stage > 40:
		value *= difficulty_multiplier("guardian_attack", stage)
	else:
		var final_scale: Dictionary = progression.progression_config.get("combat_difficulty", {}).get("final_boss", {}).get(str(stage), {})
		value *= float(final_scale.get("attack", 1.0))
	return maxf(1.0, value)

func breakthrough_actor(actor_id: String) -> bool:
	if not progression.breakthrough_actor(actor_id, native_world_tier(actor_id), maximum_unlocked_world_tier()): return false
	rebuild_party()
	log_message.emit("★ %s完成破限" % actor_display_name(actor_id))
	return true

func apply_playable_melee_survival_baseline() -> void:
	# Balance only recruitable hero templates. Enemy and boss templates are kept
	# completely separate, and the resulting max_hp remains the single base value
	# used by level/equipment refreshes (so the ratio is never compounded).
	var tank_hp_by_world: Dictionary = {}
	var maximum_hero_hp_by_world: Dictionary = {}
	for hero_id in ProgressionManagerScript.ALL_HERO_IDS:
		var data: Dictionary = actors.get(hero_id, {})
		if data.is_empty(): continue
		var world := str(data.get("world", ""))
		var hero_hp := float(data.get("max_hp", 1.0))
		maximum_hero_hp_by_world[world] = maxf(float(maximum_hero_hp_by_world.get(world, 0.0)), hero_hp)
		if str(data.get("combat_role", "")) == "tank" or str(data.get("combat_style", "")) == "tank":
			tank_hp_by_world[world] = maxf(float(tank_hp_by_world.get(world, 0.0)), hero_hp)
	for hero_id in ProgressionManagerScript.ALL_HERO_IDS:
		var data: Dictionary = actors.get(hero_id, {})
		if data.is_empty() or str(data.get("combat_style", "")) != "melee" or str(data.get("combat_role", "")) == "tank": continue
		var world := str(data.get("world", ""))
		var reference_hp := float(tank_hp_by_world.get(world, 0.0))
		if reference_hp <= 0.0:
			# Worlds without a formal tank keep their strongest existing frontliner
			# as the warrior benchmark instead of borrowing another world's scale.
			reference_hp = float(maximum_hero_hp_by_world.get(world, float(data.get("max_hp", 1.0)))) / 0.90
		var role_text := str(data.get("role", ""))
		var is_assassin := "刺客" in role_text or (str(data.get("target_priority", "")) == "low_health_enemy" and float(data.get("move_speed", 0.0)) >= 120.0 and float(data.get("attack_interval", 99.0)) <= 0.75)
		var ratio := 0.80 if is_assassin else 0.90
		data["melee_archetype"] = "assassin" if is_assassin else "warrior"
		data["survival_reference_hp"] = reference_hp
		data["max_hp"] = maxf(float(data.get("max_hp", 1.0)), ceilf(reference_hp * ratio))

func apply_playable_attack_interval_baseline() -> void:
	# Normalize only recruitable hero templates once after data loading.
	for hero_id in ProgressionManagerScript.ALL_HERO_IDS:
		var data: Dictionary = actors.get(hero_id, {})
		if data.is_empty(): continue
		data.attack_interval = clampf(float(data.get("attack_interval", 1.0)), 0.95, 1.05)

func _process(delta: float) -> void:
	if is_paused:
		return
	if game_over:
		if auto_retry_enabled and retry_timer >= 0.0:
			retry_timer -= delta
			if retry_timer <= 0.0: retry_after_defeat()
		return
	elapsed += delta
	adventure.tick(delta)
	party_hud_timer = maxf(0.0, party_hud_timer - delta)
	if party_hud_dirty and party_hud_timer <= 0.0:
		party_hud_dirty = false
		party_hud_timer = 0.1
		party_changed.emit(heroes)
	if stage_transition_timer >= 0.0:
		stage_transition_timer -= delta
		if stage_transition_timer <= 0.0:
			stage_transition_timer = -1.0
			continue_after_stage()
		return
	ai_trace_timer += delta
	if ai_trace_timer >= 0.25:
		ai_trace_timer = 0.0
		record_ai_snapshot()
	if enemies.is_empty() and has_damage_dealer_in_party():
		spawn_timer += delta
		if spawn_timer >= 2.2:
			spawn_timer = 0.0
			spawn_wave()
	stats_changed.emit(kills, elapsed, current_stage_wave())

func _store_combat_log(message: String) -> void:
	combat_log.append("[%s] %s" % [Time.get_time_string_from_system(), message])
	if combat_log.size() > 160: combat_log.pop_front()

func clear_combat_log() -> void:
	combat_log.clear()
	log_message.emit("战斗日志已由玩家手动清空。")

func infer_skill_function(effect: String) -> String:
	if effect in ["heal", "hot", "team_hot", "cleanse", "regeneration"]: return "healing"
	if effect in ["shield", "damage_reduction", "damage_share", "stat_guard", "counter"]: return "defense"
	if effect in ["stun", "freeze", "poison", "armor_break", "shock", "status_mastery", "status_amplifier"]: return "control"
	if effect in ["evasion", "move_speed"]: return "mobility"
	if effect in ["cooldown", "stat_attack", "attack_speed", "critical", "friend_guard"]: return "support"
	return "damage"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_battle"):
		is_paused = not is_paused
		battle_state_changed.emit("已暂停" if is_paused else "自动战斗中")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local := to_local(event.position)
		if Rect2(Vector2.ZERO, BattleMapScript.ARENA_SIZE).has_point(local) and not point_blocked(local):
			battle_map.set_rally(local)
			for i in range(heroes.size()):
				if is_instance_valid(heroes[i]) and not heroes[i].dead:
					heroes[i].set_rally(local + Vector2((i % 2) * 38 - 19, (i / 2) * 38 - 19))
			log_message.emit("队伍移动至新的集结点")

func find_closest_enemy(seeker):
	var pool: Array = enemies if seeker.faction == "heroes" else heroes
	var closest
	var best := INF
	for candidate in pool:
		if is_instance_valid(candidate) and not candidate.dead:
			var distance = seeker.position.distance_squared_to(candidate.position)
			if distance < best:
				best = distance
				closest = candidate
	return closest

func select_combat_target(seeker):
	var pool: Array = enemies if seeker.faction == "heroes" else heroes
	var available: Array = []
	for candidate in pool:
		if is_instance_valid(candidate) and not candidate.dead:
			available.append(candidate)
	if available.is_empty(): return null
	if seeker.faction != "heroes":
		var mechanic := str(seeker.actor_data.get("boss_mechanic", ""))
		if mechanic == "backline_hunt":
			for candidate in available:
				if candidate.actor_data.get("combat_role", "") in ["healer", "ranged_dps"]: return candidate
		if mechanic == "high_threat_hunt":
			available.sort_custom(func(a, b): return a.attack > b.attack)
			return available[0]
		return find_closest_enemy(seeker)
	match seeker.actor_data.get("target_priority", "closest"):
		"intercept_backline":
			for enemy in available:
				if is_instance_valid(enemy.target) and enemy.target.actor_data.get("combat_role", "") in ["ranged_dps", "healer"]:
					return enemy
		"low_health_enemy":
			available.sort_custom(func(a, b): return a.hp / a.max_hp < b.hp / b.max_hp)
			return available[0]
		"high_threat":
			available.sort_custom(func(a, b): return a.attack > b.attack)
			return available[0]
		"status_target":
			for enemy in available:
				if enemy.poison_time <= 0.0: return enemy
	return find_closest_enemy(seeker)

func formation_point(actor_id: String, slot_index: int) -> Vector2:
	var formation := str(actors.get(actor_id, {}).get("formation_position", "front_flank"))
	var y := 135.0 + slot_index * 88.0
	match formation:
		"front_center": return Vector2(315, y)
		"front_flank": return Vector2(245, y)
		"back_center": return Vector2(105, y)
		"back_flank": return Vector2(135, y)
	return Vector2(200, y)

func tactical_ranged_point(unit, threat) -> Vector2:
	var preferred := float(unit.actor_data.get("preferred_range", unit.attack_range * 0.85))
	var away: Vector2 = threat.position.direction_to(unit.position)
	if away.length_squared() < 0.01: away = Vector2.LEFT
	var desired: Vector2 = threat.position + away.normalized() * preferred
	desired.x = clampf(desired.x, 28.0, BattleMapScript.ARENA_SIZE.x - 28.0)
	desired.y = clampf(desired.y, 38.0, BattleMapScript.ARENA_SIZE.y - 28.0)
	return desired

func record_ai_snapshot() -> void:
	for hero in heroes:
		if not is_instance_valid(hero) or hero.dead: continue
		var enemy = find_closest_enemy(hero)
		ai_trace.append({"time": elapsed, "test_wave": ai_test_wave, "actor_id": hero.actor_id, "role": hero.actor_data.get("combat_role", ""), "position": hero.position, "enemy_distance": hero.position.distance_to(enemy.position) if enemy != null else -1.0, "velocity": hero.velocity, "target": hero.target.actor_id if is_instance_valid(hero.target) else "", "action": hero.current_action})
	if ai_trace.size() > 1200: ai_trace = ai_trace.slice(ai_trace.size() - 1200)

func lowest_health_ally(seeker, max_distance: float = 260.0):
	var pool: Array = heroes if seeker.faction == "heroes" else enemies
	var result
	var ratio := 2.0
	for ally in pool:
		if is_instance_valid(ally) and not ally.dead and seeker.position.distance_to(ally.position) <= max_distance:
			var current = ally.hp / ally.max_hp
			if current < ratio:
				ratio = current
				result = ally
	return result

func enemies_near(center: Vector2, source_faction: String, radius: float, limit: int) -> Array:
	var pool: Array = enemies if source_faction == "heroes" else heroes
	var found: Array = []
	for candidate in pool:
		if is_instance_valid(candidate) and not candidate.dead and candidate.position.distance_to(center) <= radius:
			found.append(candidate)
			if found.size() >= limit:
				break
	return found

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	# With fixed blockers removed, a direct path is both more stable and cheaper.
	# Keep the method as the single movement API for compatibility with tests and
	# future temporary mechanics.
	return PackedVector2Array([to])

func nearest_open_cell(cell: Vector2i) -> Vector2i:
	cell.x = clampi(cell.x, 0, 33)
	cell.y = clampi(cell.y, 0, 16)
	if not astar.is_point_solid(cell):
		return cell
	for radius in range(1, 5):
		for x in range(cell.x - radius, cell.x + radius + 1):
			for y in range(cell.y - radius, cell.y + radius + 1):
				var test := Vector2i(x, y)
				if astar.is_in_boundsv(test) and not astar.is_point_solid(test):
					return test
	return cell

func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 32.0), floori(point.y / 32.0))

func point_blocked(point: Vector2) -> bool:
	return not Rect2(Vector2(18, 28), BattleMapScript.ARENA_SIZE - Vector2(36, 46)).has_point(point)

func _on_unit_died(unit) -> void:
	if unit.faction == "enemies":
		if unit.reward_claimed:
			return
		unit.reward_claimed = true
		if bool(unit.actor_data.get("stage_boss", false)):
			stage_boss_defeated = true
			stage_boss_active = false
		enemies.erase(unit)
		kills += 1
		progression.add_gold(1 + int(worlds_config.maps.get(current_map_id, {}).get("level", 1)))
		if is_instance_valid(unit.last_damage_source):
			unit.last_damage_source.on_kill_trigger()
			combat_stats.record_kill(stats_actor_id(unit.last_damage_source))
		elif not str(unit.last_damage_source_id).is_empty():
			# Delayed damage may outlive its source node. Preserve attribution, but
			# never invoke on-kill effects on a dead/freed unit.
			combat_stats.record_kill(str(unit.last_damage_source_id))
		var reward_type := combat_enemy_type(unit)
		var earned_xp: int = progression.experience_for_kill(unit.monster_level, reward_type, progression.team_level)
		var team_leveled: bool = progression.add_team_experience(earned_xp, false, "%s Lv.%d" % [reward_type, unit.monster_level])
		if team_leveled:
			log_message.emit("★ 冒险团等级提升至 Lv.%d" % progression.team_level)
			for hero in heroes:
				if is_instance_valid(hero):
					hero.refresh_progression_stats()
		progression.changed.emit()
		progression.save_to_disk()
		roll_skill_book_drop(unit)
		if adventure.on_enemy_defeated(unit):
			log_message.emit("★ 奇遇完成，奖励已进入同一背包与资源存档。")
			return
		if not active_rift_context.is_empty() and unit.actor_data.has("rift_floor"):
			var completed_world := str(active_rift_context.world)
			var rift_reward: Dictionary = adventure.resolve_rift_victory()
			if rift_reward.is_empty():
				return
			var stone_text := "、破限石×1" if int(rift_reward.get("breakthrough_stone", 0)) > 0 else ""
			log_message.emit("★ 秘境第%d层完成：%d金币、材料×%d%s及%s。" % [int(rift_reward.get("floor", 0)), int(rift_reward.get("gold", 0)), int(rift_reward.get("material", 0)), stone_text, str(rift_reward.get("equipment", {}).get("name", "装备"))])
			active_rift_context.clear()
			var next_mode := str(rift_reward.get("next_mode", ""))
			if next_mode in ["climb", "repeat"]: call_deferred("continue_rift_auto", completed_world, int(rift_reward.next_floor), next_mode)
			else: call_deferred("return_from_special_combat", true)
			return
		if not active_boss_id.is_empty() and combat_enemy_type(unit) == "boss":
			resolve_boss_victory(active_boss_id)
		else:
			roll_equipment_drop(unit)
			roll_material_drop()
			if enemies.is_empty():
				resolve_stage_wave(unit)
	else:
		heroes.erase(unit)
		party_changed.emit(heroes)
		if heroes.is_empty():
			if not active_rift_context.is_empty():
				var failed_floor := int(active_rift_context.get("floor", 1))
				clear_rift_session(true)
				battle_state_changed.emit("秘境第%d层挑战失败，已暂停爬层并返回主线" % failed_floor)
				call_deferred("return_from_special_combat", false)
			else:
				game_over = true
				consecutive_defeats += 1
				retry_timer = 3.0
				log_message.emit("队伍全灭：3秒后自动重试；连续失败将回退安全关卡。")
				battle_state_changed.emit("战斗失败 · 3秒后自动重试")

func retry_after_defeat() -> void:
	if is_paused: return
	var stage := int(worlds_config.maps.get(current_map_id, {}).get("global_stage", 1))
	if consecutive_defeats >= 3 and stage > 1:
		var safe_stage := clampi(mini(stage - 1, progression.completed_stages.size()), 1, 40)
		var safe_map := stage_id_for_number(safe_stage)
		if not safe_map.is_empty():
			current_map_id = safe_map
			progression.set_last_stage(safe_map, safe_stage)
			battle_map.map_id = safe_map
			battle_map.queue_redraw()
			log_message.emit("连续失败，已回退全局第%d关继续挂机。" % safe_stage)
			consecutive_defeats = 0
	clear_combatants()
	wave = 1
	stage_cleared = false
	spawn_party()
	if has_damage_dealer_in_party(): spawn_wave()
	battle_state_changed.emit("自动重试完成 · 继续挂机")

func _on_combat_event(message: String) -> void:
	log_message.emit(message)

func _on_health_changed(unit) -> void:
	# Enemy HP already redraws on its own unit. Rebuilding the full party HUD for
	# every enemy hit (especially multi-hit/DoT) caused escalating UI work and
	# made long battles look as if attacks no longer reached damage settlement.
	if is_instance_valid(unit) and unit.faction == "heroes":
		party_hud_dirty = true

func _on_equipment_changed(actor_id: String) -> void:
	for hero in heroes:
		if is_instance_valid(hero) and hero.actor_id == actor_id:
			hero.apply_equipment_stats(inventory.get_actor_stats(actor_id), equipment_config.get("rules", {}))
			party_changed.emit(heroes)
			return

func roll_equipment_drop(defeated_unit) -> void:
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var table: Dictionary = loot_config.get("grassland_crossing", {})
	var chance := 1.0 if loot_test_mode else float(map_data.get("drop_chance", 0.4))
	if randf() > chance:
		return
	var level := int(map_data.get("level", 1)) + maxi(0, wave - 2)
	var quality: String = equipment_generator.roll_quality(loot_test_mode)
	var source := "%s · 第%d波" % [defeated_unit._name(), maxi(1, wave - 1)]
	var item: Dictionary = equipment_generator.generate(level, source, quality)
	var auto_result := auto_process_new_equipment(item, true)
	if not auto_result.is_empty():
		combat_stats.resources.equipment += 1
		var auto_quality_info: Dictionary = equipment_config.get("qualities", {}).get(quality, {})
		spawn_ring(defeated_unit.position, Color(auto_quality_info.get("color", "FFFFFF")))
	elif inventory.add_item(item):
		combat_stats.resources.equipment += 1
		var quality_info: Dictionary = equipment_config.get("qualities", {}).get(quality, {})
		var important := int(quality_info.get("rank", 0)) >= 2
		log_message.emit(("★ 获得 " if important else "获得 ") + item.get("name", "装备") + "（自动拾取）")
		spawn_ring(defeated_unit.position, Color(quality_info.get("color", "FFFFFF")))
		loot_obtained.emit(item)
	else:
		log_message.emit("背包已满，未能拾取装备")

func auto_process_new_equipment(item: Dictionary, eligible: bool = true) -> Dictionary:
	# This function is called only for a newly generated ordinary reward and runs
	# before InventoryManager.add_item(), so eligible drops still convert at 120/120.
	if not eligible or item.is_empty() or bool(item.get("_auto_processed", false)) or bool(item.get("locked", false)) or bool(item.get("auto_process_protected", false)) or bool(item.get("world_legendary", false)) or str(item.get("quality", "")) == "red":
		return {}
	if str(item.get("instance_id", "")).is_empty() or str(item.get("slot", "")).is_empty():
		return {}
	if shop.is_equipped(str(item.get("instance_id", ""))):
		return {}
	var settings: Dictionary = progression.auto_equipment_settings
	var rank := int(item.get("quality_rank", equipment_config.get("qualities", {}).get(item.get("quality", "white"), {}).get("rank", 0)))
	var quality_ranks := {"white":0, "green":1, "blue":2, "purple":3, "orange":4}
	var sell_match := bool(settings.get("sell_enabled", false)) and rank <= int(quality_ranks.get(str(settings.get("sell_max_quality", "white")), 0))
	var dismantle_match := bool(settings.get("dismantle_enabled", false)) and rank <= int(quality_ranks.get(str(settings.get("dismantle_max_quality", "white")), 0))
	if not sell_match and not dismantle_match:
		return {}
	var action := "dismantle" if dismantle_match and (not sell_match or str(settings.get("priority", "dismantle")) == "dismantle") else "sell"
	var quality_name := str(equipment_config.get("qualities", {}).get(item.get("quality", "white"), {}).get("name", item.get("quality", "white")))
	if action == "sell":
		item["_auto_processed"] = true
		var gold_gain: int = shop.sell_price(item)
		progression.gold += gold_gain
		progression.record_transaction("自动出售装备", item.get("name", item.instance_id), gold_gain)
		combat_stats.resources.auto_sold_count += 1
		combat_stats.resources.auto_sold_gold += gold_gain
		progression.changed.emit()
		progression.save_to_disk()
		log_message.emit("自动出售：%s装备×1，获得金币%d" % [quality_name, gold_gain])
		return {"action":"sell", "gold":gold_gain, "count":1}
	var material_gain: int = crafting.dismantle_value(item)
	if material_gain <= 0:
		return {}
	item["_auto_processed"] = true
	progression.materials.salvage_dust = int(progression.materials.get("salvage_dust", 0)) + material_gain
	progression.record_transaction("自动分解装备", "%s，重铸材料+%d" % [item.get("name", item.instance_id), material_gain], 0)
	combat_stats.resources.auto_dismantled_count += 1
	combat_stats.resources.auto_dismantled_material += material_gain
	combat_stats.resources.materials += material_gain
	progression.changed.emit()
	progression.save_to_disk()
	log_message.emit("自动分解：%s装备×1，获得重铸材料%d" % [quality_name, material_gain])
	return {"action":"dismantle", "material":material_gain, "count":1}

func get_hero(actor_id: String):
	for hero in heroes:
		if is_instance_valid(hero) and hero.actor_id == actor_id:
			return hero
	return null

func roll_material_drop() -> void:
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var bounds: Array = map_data.get("material_drop", [1, 2])
	var amount := randi_range(int(bounds[0]), int(bounds[1]))
	progression.add_material(map_data.get("material", "three_kingdoms_token"), amount)
	combat_stats.resources.materials += amount

func roll_skill_book_drop(defeated_unit) -> void:
	var chance := skill_book_drop_chance(defeated_unit)
	if randf() > chance: return
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var world_name := str(map_data.get("world", "三国"))
	var candidates: Array[String] = []
	for skill_id in general_skills_config:
		if str(general_skills_config[skill_id].get("world", "")) == world_name: candidates.append(str(skill_id))
	if candidates.is_empty(): return
	var skill_id: String = candidates[randi() % candidates.size()]
	progression.grant_skill_book(skill_id, 1, defeated_unit._name())
	log_message.emit("★ 获得技能书【%s】" % general_skills_config[skill_id].get("name", skill_id))

func combat_enemy_type(unit) -> String:
	var enemy_type := str(unit.enemy_type)
	return enemy_type if enemy_type in ["normal", "elite", "boss"] else "normal"

func skill_book_drop_chance(defeated_unit) -> float:
	match combat_enemy_type(defeated_unit):
		"elite": return 0.14
		"boss": return 1.0
	return 0.025

func switch_map(map_id: String) -> bool:
	if not worlds_config.maps.has(map_id):
		return false
	var stage := int(worlds_config.maps[map_id].get("global_stage", 1))
	if not progression.can_enter_stage(stage):
		var world_name := str(worlds_config.maps[map_id].get("world", "未知世界"))
		log_message.emit("%s尚未开放或关卡未解锁：请按主线顺序通关前一关。" % world_name)
		return false
	clear_rift_session(true)
	clear_combatants()
	current_map_id = map_id
	progression.set_last_stage(map_id, stage)
	battle_map.map_id = map_id
	battle_map.queue_redraw()
	active_boss_id = ""
	wave = 1
	stage_cleared = false
	stage_boss_active = false
	spawn_party()
	spawn_wave()
	world_changed.emit(map_id)
	log_message.emit("前往【%s】" % worlds_config.maps[map_id].name)
	return true

func start_boss(boss_id: String) -> bool:
	if not worlds_config.bosses.has(boss_id):
		return false
	var boss_data: Dictionary = worlds_config.bosses[boss_id]
	if not progression.is_stage_complete(int(boss_data.get("required_stage", 20))):
		log_message.emit("传奇挑战尚未开放：请先完成对应世界主线。")
		return false
	clear_rift_session(true)
	clear_combatants()
	active_boss_id = boss_id
	spawn_party()
	var boss = spawn_unit(boss_data.actor, "enemies", Vector2(875, 260))
	boss.monster_level = int(boss_data.get("required_stage", 20))
	log_message.emit("传奇挑战开始：【%s】" % boss_data.name)
	return true

func start_rift_combat(context: Dictionary, profile: Dictionary) -> void:
	clear_combatants()
	active_boss_id = ""
	active_rift_context = context.duplicate(true)
	spawn_party()
	var affixes: Array = profile.get("affixes", [])
	var overrides := {"name":profile.get("name", "秘境Boss"), "rift_floor":int(context.floor), "rift_world":str(context.world), "rift_affixes":affixes, "boss_id":"rift_" + str(context.world)}
	var boss = spawn_unit(str(profile.actor), "enemies", Vector2(875, 260), overrides)
	boss.enemy_type = "boss"; boss.monster_level = int(context.floor)
	boss.max_hp = float(profile.health); boss.hp = boss.max_hp; boss.attack = float(profile.attack); boss.defense = float(profile.defense)
	battle_state_changed.emit("大秘境第%d层挑战中" % int(context.floor))
	log_message.emit("进入%s；词缀：%s" % [profile.name, "、".join(affixes)])

func return_from_special_combat(success: bool) -> void:
	clear_rift_session(false)
	clear_combatants()
	wave = 1
	stage_cleared = false
	spawn_party()
	if has_damage_dealer_in_party(): spawn_wave()
	if success: battle_state_changed.emit("秘境结算完成 · 返回主线挂机")

func continue_rift_auto(world_id: String, floor: int, mode: String = "climb") -> void:
	clear_combatants()
	if not adventure.start_rift(world_id, floor):
		return_from_special_combat(true)
	else:
		log_message.emit(("固定刷层：再次挑战第%d层。" if mode == "repeat" else "自动爬层：继续挑战第%d层。") % floor)

func rift_combat_running() -> bool:
	if active_rift_context.is_empty(): return false
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.actor_data.has("rift_floor"):
			return true
	return false

func clear_rift_session(stop_automatic: bool = true) -> void:
	var context: Dictionary = active_rift_context if not active_rift_context.is_empty() else adventure.active_rift if adventure != null else {}
	if stop_automatic and not context.is_empty():
		var world_id := str(context.get("world", ""))
		if progression.rift_progress.has(world_id):
			var state: Dictionary = progression.rift_progress[world_id]
			state.auto_climb = false
			state.repeat_floor = false
			state.selected_floor = maxi(1, int(context.get("floor", state.get("selected_floor", 1))))
			progression.save_to_disk()
	if adventure != null: adventure.active_rift.clear()
	active_rift_context.clear()

func clear_combatants() -> void:
	for unit in heroes + enemies:
		if is_instance_valid(unit):
			unit.queue_free()
	heroes.clear()
	enemies.clear()
	game_over = false
	spawn_timer = 0.0
	stage_boss_active = false
	stage_boss_spawned = false
	stage_boss_defeated = false
	stage_resolution_started = false
	stage_transition_timer = -1.0

func rebuild_party() -> void:
	clear_rift_session(true)
	clear_combatants()
	active_boss_id = ""
	wave = 1
	stage_cleared = false
	spawn_party()
	if has_damage_dealer_in_party():
		spawn_wave()
		battle_state_changed.emit("自动战斗中")
	else:
		battle_state_changed.emit("等待招募并上阵输出角色")

func assign_party_member(index: int, actor_id: String) -> bool:
	if index < 0 or index >= progression.party.size() or (not actor_id.is_empty() and actor_id not in progression.roster):
		return false
	var outgoing := str(progression.party[index])
	var incoming_index: int = progression.party.find(actor_id) if not actor_id.is_empty() else -1
	var should_swap_equipment: bool = not actor_id.is_empty() and incoming_index < 0 and not outgoing.is_empty() and outgoing != actor_id
	if should_swap_equipment and not inventory.can_swap_actor_equipment(outgoing, actor_id):
		log_message.emit("替换失败：%s" % inventory.last_error)
		return false
	if should_swap_equipment and not inventory.swap_actor_equipment(outgoing, actor_id, false):
		return false
	if not progression.set_party_member(index, actor_id, false):
		if should_swap_equipment: inventory.swap_actor_equipment(outgoing, actor_id, false)
		return false
	if should_swap_equipment: inventory.save_to_disk()
	progression.save_to_disk()
	return true

func has_damage_dealer_in_party() -> bool:
	for actor_id in progression.party:
		if str(actor_id).is_empty():
			continue
		if actors.get(actor_id, {}).get("basic_action", "damage") != "heal":
			return true
	return false

func resolve_stage_wave(defeated_unit = null) -> void:
	if stage_cleared or stage_resolution_started:
		return
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var active_wave := wave - 1
	var target_wave := int(map_data.get("waves_to_clear", 3))
	if active_wave < target_wave:
		return
	if not str(map_data.get("main_boss", "")).is_empty():
		# Compatibility for deterministic callers that pass the defeated boss
		# directly. Runtime progression records this at the boss's own death, so a
		# later-dying summon cannot erase the result.
		if defeated_unit != null and combat_enemy_type(defeated_unit) == "boss":
			stage_boss_spawned = true
			stage_boss_defeated = true
		if not stage_boss_spawned or not stage_boss_defeated:
			return
	if not enemies.is_empty():
		return
	stage_resolution_started = true
	var stage := int(map_data.get("global_stage", 1))
	var first_clear: bool = not progression.is_stage_complete(stage)
	if first_clear:
		if not progression.complete_stage(stage):
			stage_resolution_started = false
			var message := "主线第%d关战斗完成，但进度写入被拒绝（最高可进入第%d关，完成记录%d关）；已停止切关并保留现场诊断。" % [stage, progression.highest_unlocked_stage(), progression.completed_stages.size()]
			push_error(message)
			log_message.emit(message)
			battle_state_changed.emit("第%d关进度写入失败，请重试本关" % stage)
			return
		progression.add_gold(int(map_data.get("first_clear_gold", 0)))
		var first_material := int(map_data.get("first_clear_material", 0))
		progression.add_material(str(map_data.get("material", "three_kingdoms_token")), first_material)
		combat_stats.resources.materials += first_material
		# Mainline maps identify their boss by actor template. Resolve the permanent
		# recruitment gate from that template instead of the runtime stage_* id.
		var boss_actor_id := str(map_data.get("main_boss", ""))
		var clear_boss_id := str(actors.get(boss_actor_id, {}).get("boss_id", map_data.get("boss_id", "")))
		if worlds_config.bosses.has(clear_boss_id):
			var boss_data: Dictionary = worlds_config.bosses[clear_boss_id]
			progression.unlock_boss_actor(clear_boss_id, str(boss_data.get("unlock_actor", "")))
		if stage == 10:
			log_message.emit("★ 三国第10关通关！宝可梦世界已永久开放。")
		elif stage == 20:
			log_message.emit("★ 宝可梦第20关通关！龙族世界已永久开放。")
		elif stage == 30:
			log_message.emit("★ 龙族第30关通关！逆水寒世界已永久开放。")
		elif stage == 40:
			log_message.emit("★ 逆水寒第40关通关！魔兽世界已永久开放。")
		elif stage == 50:
			log_message.emit("★ 魔兽世界第50关通关！金庸世界已永久开放。")
		elif stage == 60:
			log_message.emit("★ 金庸第60关通关！秦时明月世界已永久开放。")
		elif stage == 70:
			log_message.emit("★ 秦时明月第70关通关！火影忍者世界已永久开放。")
		elif stage == 80:
			log_message.emit("★ 火影忍者第80关通关！黄易世界已永久开放。")
		elif stage == 90:
			log_message.emit("★ 黄易第90关通关！风云世界已永久开放。")
		elif stage == 100:
			log_message.emit("★ 全100关主线通关！十世界秘境上限已开放至100层。")
		else:
			log_message.emit("★ 第%d关通关，第%d关已解锁。" % [stage, stage + 1])
		battle_state_changed.emit("主线第%d关已通关" % stage)
	else:
		log_message.emit("第%d关挂机轮次完成，常规掉落已结算。" % stage)
	stage_cleared = true
	stage_boss_active = false
	stage_transition_timer = 2.0

func continue_after_stage() -> void:
	var stage := int(worlds_config.maps.get(current_map_id, {}).get("global_stage", 1))
	if progression.auto_push and stage < progression.main_stage_limit():
		var next_id := stage_id_for_number(stage + 1)
		if not next_id.is_empty() and progression.can_enter_stage(stage + 1):
			switch_map(next_id)
			return
	clear_combatants()
	wave = 1
	stage_cleared = false
	spawn_party()
	if has_damage_dealer_in_party(): spawn_wave()
	battle_state_changed.emit("重复挂机第%d关" % stage)

func set_auto_push(enabled: bool) -> void:
	progression.auto_push = enabled
	progression.changed.emit()
	progression.save_to_disk()
	log_message.emit("自动推关已%s" % ("开启" if enabled else "关闭"))

func stage_id_for_number(stage: int) -> String:
	for map_id in worlds_config.maps:
		if int(worlds_config.maps[map_id].get("global_stage", 0)) == stage:
			return map_id
	return ""

func resolve_boss_victory(boss_id: String) -> void:
	var data: Dictionary = worlds_config.bosses[boss_id]
	var first: bool = progression.unlock_boss_actor(boss_id, data.unlock_actor)
	if first:
		log_message.emit("★ 首次击败%s，永久解锁%s！" % [data.name, actors[data.unlock_actor].name])
	else:
		progression.add_material(data.repeat_material, int(data.repeat_amount))
		combat_stats.resources.materials += int(data.repeat_amount)
		log_message.emit("再次击败%s，获得材料 ×%d" % [data.name, data.repeat_amount])
	active_boss_id = ""

func strategy_allows(unit) -> bool:
	var preset: Dictionary = progression.strategy_presets.get(progression.active_strategy, {})
	var self_ratio: float = unit.hp / maxf(1.0, unit.max_hp)
	if unit.skill_data.get("type", "") == "self_heal":
		return self_ratio < float(unit.skill_data.get("health_threshold", preset.get("self_hp", 0.45)))
	if unit.skill_data.get("type", "") == "heal_aura":
		var ally = lowest_health_ally(unit, unit.effective_cast_range(float(unit.skill_data.get("range", 240.0))))
		return ally != null and ally.hp / ally.max_hp <= float(preset.get("ally_hp", 0.65))
	if not unit.exclusive_skill_requires_enemy_target():
		return true
	return enemies_near(unit.position, unit.faction, unit.effective_cast_range(float(unit.skill_data.get("range", 180.0))), 99).size() >= int(preset.get("enemy_count", 1))

func on_damage(source, target, amount: float, context: Dictionary) -> void:
	var source_id := stats_actor_id(source) if is_instance_valid(source) else str(context.get("source_actor_id", ""))
	var target_id := stats_actor_id(target)
	combat_stats.record_damage(source_id, target_id, amount, context.get("kind", "skill"), stats_damage_source_id(source, context))
	if not context.get("allow_triggers", true):
		return
	if is_instance_valid(source) and is_instance_valid(target) and str(context.get("kind", "")) == "skill":
		source.trigger_general_on_hit(target)
	# Character passives remain intact; only equipment-triggered reflection was removed.
	if is_instance_valid(source) and target.passive_skill_id == "low_hp_rage" and target.hp / target.max_hp < 0.5:
		target.battle.note_passive(target.actor_id, target.passive_skill_id)
		source.take_damage(amount * target.passive_value(), target, false, {"kind": "effect", "skill_id":"passive:" + str(target.passive_skill_id), "allow_triggers": false})

func stats_damage_source_id(source, context: Dictionary) -> String:
	var kind := str(context.get("kind", "skill"))
	if is_instance_valid(source) and bool(source.get("is_summon")):
		return "summon:" + str(source.actor_id)
	if kind == "basic": return "basic"
	var skill_id := str(context.get("skill_id", ""))
	if skill_id.is_empty(): skill_id = str(context.get("source_snapshot", {}).get("skill_id", ""))
	if skill_id.is_empty() and is_instance_valid(source):
		if kind == "skill": skill_id = str(source.actor_data.get("skill", ""))
		elif kind == "passive": skill_id = "passive:" + str(source.passive_skill_id)
	if skill_id.is_empty(): skill_id = "effect"
	if bool(context.get("burn", false)): return skill_id + ":burn"
	if bool(context.get("poison", false)): return skill_id + ":poison"
	if bool(context.get("frost", false)): return skill_id + ":frost"
	return skill_id

func record_damage_resolution(source, target, result: Dictionary, context: Dictionary) -> void:
	var source_id: String = str(source.actor_id) if is_instance_valid(source) else str(context.get("source_actor_id", ""))
	var target_id: String = target.actor_id if is_instance_valid(target) else ""
	var row := {
		"time":elapsed, "attacker":source_id, "target":target_id,
		"target_hp":float(result.get("hp_before", 0.0)), "attack_type":str(context.get("kind", "unknown")),
		"skill_id":str(context.get("skill_id", "")), "raw":float(result.get("raw", 0.0)),
		"defense":float(result.get("defense", 0.0)), "reduction":float(result.get("reduction", 0.0)),
		"shield_absorbed":float(result.get("shield_absorbed", 0.0)), "hp_damage":float(result.get("hp_damage", 0.0)),
		"reason":str(result.get("reason", "unknown")), "stage":int(worlds_config.maps.get(current_map_id, {}).get("global_stage", 1)),
		"wave":maxi(1, wave - 1)
	}
	if is_instance_valid(target) and target.faction == "enemies" and float(result.get("shield_absorbed", 0.0)) > 0.0:
		combat_stats.record_shield_damage(stats_actor_id(source) if is_instance_valid(source) else str(context.get("source_actor_id", "")), float(result.shield_absorbed), str(context.get("kind", "skill")), stats_damage_source_id(source, context))
	damage_trace.append(row)
	if damage_trace.size() > 600: damage_trace.pop_front()
	if source_id.is_empty() or target_id.is_empty(): return
	var key := source_id + "->" + target_id
	var effective := float(row.hp_damage) + float(row.shield_absorbed)
	if effective > 0.0 or row.reason in ["evaded", "target_dead"]:
		zero_damage_streaks[key] = 0
		return
	zero_damage_streaks[key] = int(zero_damage_streaks.get(key, 0)) + 1
	if int(zero_damage_streaks[key]) >= 3:
		var diagnostic: Dictionary = row.duplicate(true)
		diagnostic["streak"] = int(zero_damage_streaks[key])
		damage_anomalies.append(diagnostic)
		if damage_anomalies.size() > 60: damage_anomalies.pop_front()
		push_warning("ZERO_DAMAGE_DIAGNOSTIC %s" % JSON.stringify(diagnostic))

func on_heal(source, amount: float, source_snapshot: Dictionary = {}) -> void:
	var source_id := stats_actor_id(source) if is_instance_valid(source) else str(source_snapshot.get("actor_id", ""))
	if not source_id.is_empty():
		var source_key := str(source_snapshot.get("skill_id", ""))
		if source_key.is_empty(): source_key = "healing"
		combat_stats.record_heal(source_id, amount, source_key)

func on_friendly_shield_absorbed(source_id: String, source_key: String, amount: float) -> void:
	combat_stats.record_shield_absorb(source_id, amount, source_key if not source_key.is_empty() else "shield")

func on_skill(source) -> void:
	combat_stats.record_skill(stats_actor_id(source))
	source.on_skill_casted()
	source.on_boss_skill_cast()

func stats_actor_id(unit) -> String:
	if not is_instance_valid(unit): return ""
	if bool(unit.get("is_summon")) and not str(unit.get("summon_owner_id")).is_empty():
		return str(unit.get("summon_owner_id"))
	return str(unit.actor_id)

func stats_snapshot() -> Dictionary:
	return combat_stats.snapshot(elapsed, progression.roster)

func reset_combat_stats() -> void:
	combat_stats.reset(elapsed)
	log_message.emit("本次实时战斗统计已清空；战斗与永久成长不受影响。")

func safe_restart_game() -> Dictionary:
	is_paused = true
	auto_retry_enabled = false
	var result: Dictionary = reset_manager.perform_safe_reset(progression, inventory)
	if bool(result.get("ok", false)):
		combat_stats.reset(elapsed)
		combat_log.clear()
		clear_combatants()
		battle_state_changed.emit("旧存档已验证备份，正在载入全新冒险")
	else:
		is_paused = false
		auto_retry_enabled = true
		battle_state_changed.emit("重新开始已取消：" + str(result.get("error", "备份或校验失败")))
	return result

func note_passive(actor_id: String, passive_id: String) -> void:
	var key := actor_id + ":" + passive_id
	passive_trigger_counts[key] = int(passive_trigger_counts.get(key, 0)) + 1

func party_passive_value(effect: String) -> float:
	var total := 0.0
	for hero in heroes:
		if is_instance_valid(hero) and not hero.dead and hero.passive_data.get("effect", "") == effect:
			total += hero.passive_value()
	return total

func spawn_tracer(from: Vector2, to: Vector2, color: Color) -> void:
	if suppress_combat_visuals: return
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = color
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)

func spawn_ring(at: Vector2, color: Color) -> void:
	if suppress_combat_visuals: return
	var ring = EffectRingScript.new()
	ring.position = at
	ring.tint = color
	add_child(ring)

func restart() -> void:
	get_tree().reload_current_scene()

