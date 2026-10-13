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
var special_config: Dictionary
var shop_config: Dictionary
var passives_config: Dictionary
var inventory
var equipment_generator
var progression
var crafting
var shop
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
var effect_cooldowns: Dictionary = {}
var trigger_counts := {"crit_lightning": 0, "thorn_reflect": 0, "poison_spread": 0, "shield_burst": 0}
var passive_trigger_counts: Dictionary = {}
var stage_cleared := false
var stage_boss_active := false

func _ready() -> void:
	actors = DataLoaderScript.load_json("res://data/actors.json")
	skills = DataLoaderScript.load_json("res://data/skills.json")
	equipment_config = DataLoaderScript.load_json("res://data/equipment.json")
	loot_config = DataLoaderScript.load_json("res://data/loot_tables.json")
	worlds_config = DataLoaderScript.load_json("res://data/worlds.json")
	special_config = DataLoaderScript.load_json("res://data/special_effects.json")
	shop_config = DataLoaderScript.load_json("res://data/shop.json")
	passives_config = DataLoaderScript.load_json("res://data/passives.json")
	loot_test_mode = "--loot-test" in OS.get_cmdline_user_args() or "--equipment-test" in OS.get_cmdline_user_args() or "--v03-test" in OS.get_cmdline_user_args() or "--v031-test" in OS.get_cmdline_user_args()
	inventory = InventoryManagerScript.new()
	inventory.setup(equipment_config)
	add_child(inventory)
	if "--equipment-test" in OS.get_cmdline_user_args() or "--persistence-write" in OS.get_cmdline_user_args() or "--v03-test" in OS.get_cmdline_user_args() or "--v031-test" in OS.get_cmdline_user_args() or "--v05-test" in OS.get_cmdline_user_args() or "--v05-core-test" in OS.get_cmdline_user_args() or "--v05-shop-test" in OS.get_cmdline_user_args() or "--v05-skill-test" in OS.get_cmdline_user_args() or "--v05-system-test" in OS.get_cmdline_user_args():
		inventory.clear_test_save()
	inventory.load_from_disk()
	inventory.equipment_changed.connect(_on_equipment_changed)
	progression = ProgressionManagerScript.new()
	progression.setup()
	add_child(progression)
	progression.changed.connect(func(): progression_changed.emit())
	if worlds_config.maps.has(progression.last_stage_id):
		var saved_stage := int(worlds_config.maps[progression.last_stage_id].get("global_stage", 1))
		if progression.can_enter_stage(saved_stage):
			current_map_id = progression.last_stage_id
	equipment_generator = EquipmentGeneratorScript.new(equipment_config, loot_config, 20261012 if loot_test_mode else 0, special_config)
	crafting = CraftingManagerScript.new()
	crafting.setup(inventory, progression, equipment_config, equipment_generator)
	shop = ShopManagerScript.new()
	shop.setup(inventory, progression, equipment_generator, shop_config)
	combat_stats = CombatStatsScript.new()
	combat_stats.reset()
	battle_map = BattleMapScript.new()
	battle_map.map_id = current_map_id
	add_child(battle_map)
	setup_navigation()
	spawn_party()
	spawn_wave()

func setup_navigation() -> void:
	astar.region = Rect2i(0, 0, 34, 17)
	astar.cell_size = Vector2(32, 32)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for rect in battle_map.obstacles:
		var start := world_to_cell(rect.position - Vector2(16, 16))
		var finish := world_to_cell(rect.end + Vector2(16, 16))
		for x in range(start.x, finish.x + 1):
			for y in range(start.y, finish.y + 1):
				var cell := Vector2i(x, y)
				if astar.is_in_boundsv(cell):
					astar.set_point_solid(cell, true)

func spawn_party() -> void:
	var ids: Array = progression.party
	for i in range(ids.size()):
		var pos := Vector2(120 + (i % 2) * 70, 190 + (i / 2) * 110)
		spawn_unit(ids[i], "heroes", pos)
	party_changed.emit(heroes)

func spawn_wave() -> void:
	if game_over or stage_cleared:
		return
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var target_wave := int(map_data.get("waves_to_clear", 3))
	if not str(map_data.get("main_boss", "")).is_empty() and wave == target_wave:
		stage_boss_active = true
		spawn_unit(str(map_data.main_boss), "enemies", Vector2(875, 260))
		log_message.emit("主线第 %d 关关底Boss登场：【%s】" % [int(map_data.get("global_stage", 1)), actors.get(map_data.main_boss, {}).get("name", "Boss")])
		wave += 1
		return
	var pool: Array = map_data.get("enemy_pool", ["yellow_turban"])
	var count := mini(3 + wave, 9)
	for i in range(count):
		var id: String = pool[(i + wave) % pool.size()]
		var pos := Vector2(900 + randf_range(-50, 70), 70 + i * (380.0 / maxf(1, count - 1)) + randf_range(-18, 18))
		var enemy = spawn_unit(id, "enemies", pos)
		# Gentle wave scaling keeps the idle loop meaningful.
		enemy.max_hp *= 1.0 + (wave - 1) * 0.12
		enemy.hp = enemy.max_hp
		enemy.attack *= 1.0 + (wave - 1) * 0.07
	log_message.emit("第 %d 波敌人进入%s" % [wave, map_data.get("name", "地图")])
	wave += 1

func spawn_unit(id: String, faction: String, pos: Vector2):
	var unit = BattleUnitScript.new()
	var data: Dictionary = actors.get(id, {})
	var skill: Dictionary = skills.get(data.get("skill", ""), {})
	unit.setup(id, data, skill, faction, self)
	unit.position = pos
	unit.died.connect(_on_unit_died)
	unit.combat_event.connect(_on_combat_event)
	unit.health_changed.connect(_on_health_changed)
	add_child(unit)
	if faction == "heroes":
		heroes.append(unit)
		unit.apply_equipment_stats(inventory.get_actor_stats(id), equipment_config.get("rules", {}))
		unit.set_special_effects(inventory.get_actor_specials(id))
	else:
		enemies.append(unit)
	return unit

func _process(delta: float) -> void:
	if is_paused or game_over:
		return
	elapsed += delta
	for key in effect_cooldowns.keys():
		effect_cooldowns[key] = maxf(0.0, float(effect_cooldowns[key]) - delta)
	if enemies.is_empty():
		spawn_timer += delta
		if spawn_timer >= 2.2:
			spawn_timer = 0.0
			spawn_wave()
	stats_changed.emit(kills, elapsed, wave - 1)

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

func lowest_health_ally(seeker):
	var pool: Array = heroes if seeker.faction == "heroes" else enemies
	var result
	var ratio := 2.0
	for ally in pool:
		if is_instance_valid(ally) and not ally.dead and seeker.position.distance_to(ally.position) <= 260:
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
	var start := nearest_open_cell(world_to_cell(from))
	var finish := nearest_open_cell(world_to_cell(to))
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(finish):
		return PackedVector2Array([to])
	return astar.get_point_path(start, finish)

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
	for rect in battle_map.obstacles:
		if rect.grow(18).has_point(point):
			return true
	return false

func _on_unit_died(unit) -> void:
	if unit.faction == "enemies":
		enemies.erase(unit)
		kills += 1
		progression.add_gold(1 + int(worlds_config.maps.get(current_map_id, {}).get("level", 1)))
		if is_instance_valid(unit.last_damage_source):
			combat_stats.record_kill(unit.last_damage_source.actor_id)
		var leveled_actors: Array[String] = []
		for actor_id in progression.party:
			if progression.add_actor_experience(actor_id, 2, false):
				leveled_actors.append(actor_id)
				log_message.emit("★ %s升级至Lv.%d" % [actors.get(actor_id, {}).get("name", actor_id), progression.actor_level(actor_id)])
		progression.changed.emit()
		progression.save_to_disk()
		for actor_id in leveled_actors:
			var leveled_hero = get_hero(actor_id)
			if leveled_hero != null:
				leveled_hero.refresh_progression_stats()
		if not active_boss_id.is_empty() and unit.actor_data.has("boss_id"):
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
			game_over = true
			battle_state_changed.emit("队伍全灭 · 按 R 重新开始")

func _on_combat_event(message: String) -> void:
	log_message.emit(message)

func _on_health_changed(_unit) -> void:
	party_changed.emit(heroes)

func _on_equipment_changed(actor_id: String) -> void:
	for hero in heroes:
		if is_instance_valid(hero) and hero.actor_id == actor_id:
			hero.apply_equipment_stats(inventory.get_actor_stats(actor_id), equipment_config.get("rules", {}))
			hero.set_special_effects(inventory.get_actor_specials(actor_id))
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
	if inventory.add_item(item):
		combat_stats.resources.equipment += 1
		var quality_info: Dictionary = equipment_config.get("qualities", {}).get(quality, {})
		var important := int(quality_info.get("rank", 0)) >= 2
		log_message.emit(("★ 获得 " if important else "获得 ") + item.get("name", "装备") + "（自动拾取）")
		spawn_ring(defeated_unit.position, Color(quality_info.get("color", "FFFFFF")))
		loot_obtained.emit(item)
	else:
		log_message.emit("背包已满，未能拾取装备")

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

func switch_map(map_id: String) -> bool:
	if not worlds_config.maps.has(map_id):
		return false
	var stage := int(worlds_config.maps[map_id].get("global_stage", 1))
	if not progression.can_enter_stage(stage):
		if stage >= 11 and not progression.pokemon_world_unlocked:
			log_message.emit("宝可梦世界尚未开放：请先通关三国第10关。")
		else:
			log_message.emit("该关卡尚未解锁：请按主线顺序通关前一关。")
		return false
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
	clear_combatants()
	active_boss_id = boss_id
	spawn_party()
	spawn_unit(boss_data.actor, "enemies", Vector2(875, 260))
	log_message.emit("传奇挑战开始：【%s】" % boss_data.name)
	return true

func clear_combatants() -> void:
	for unit in heroes + enemies:
		if is_instance_valid(unit):
			unit.queue_free()
	heroes.clear()
	enemies.clear()
	game_over = false
	spawn_timer = 0.0
	stage_boss_active = false

func rebuild_party() -> void:
	clear_combatants()
	active_boss_id = ""
	spawn_party()
	spawn_wave()

func resolve_stage_wave(defeated_unit) -> void:
	var map_data: Dictionary = worlds_config.maps.get(current_map_id, {})
	var active_wave := wave - 1
	var target_wave := int(map_data.get("waves_to_clear", 3))
	if active_wave < target_wave:
		return
	if not str(map_data.get("main_boss", "")).is_empty() and not defeated_unit.actor_data.has("boss_id"):
		return
	var stage := int(map_data.get("global_stage", 1))
	if progression.complete_stage(stage):
		stage_cleared = true
		stage_boss_active = false
		if map_data.has("boss_id"):
			var boss_id := str(map_data.boss_id)
			var boss_data: Dictionary = worlds_config.bosses.get(boss_id, {})
			progression.unlock_boss_actor(boss_id, str(boss_data.get("unlock_actor", "")))
		if stage == 10:
			log_message.emit("★ 三国第10关通关！宝可梦世界已永久开放。")
		elif stage == 20:
			log_message.emit("★ 全20关主线通关！可继续挑战世界Boss与刷宝。")
		else:
			log_message.emit("★ 第%d关通关，第%d关已解锁。" % [stage, stage + 1])
		battle_state_changed.emit("主线第%d关已通关" % stage)

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
		log_message.emit("再次击败%s，获得材料 ×%d" % [data.name, data.repeat_amount])
	active_boss_id = ""

func strategy_allows(unit) -> bool:
	var preset: Dictionary = progression.strategy_presets.get(progression.active_strategy, {})
	var self_ratio: float = unit.hp / maxf(1.0, unit.max_hp)
	if unit.skill_data.get("type", "") == "self_heal":
		return self_ratio <= float(preset.get("self_hp", 0.45))
	if unit.skill_data.get("type", "") == "heal_aura":
		var ally = lowest_health_ally(unit)
		return ally != null and ally.hp / ally.max_hp <= float(preset.get("ally_hp", 0.65))
	return enemies_near(unit.position, unit.faction, float(unit.skill_data.get("range", 180)), 99).size() >= int(preset.get("enemy_count", 1))

func on_damage(source, target, amount: float, context: Dictionary) -> void:
	var source_id: String = source.actor_id if is_instance_valid(source) else ""
	combat_stats.record_damage(source_id, target.actor_id, amount, context.get("kind", "skill"))
	if not context.get("allow_triggers", true):
		return
	if context.get("critical", false) and is_instance_valid(source) and source.has_special("crit_lightning"):
		trigger_lightning(source, target)
	if is_instance_valid(source) and (target.has_special("thorn_reflect") or (target.passive_data.get("effect", "") == "low_hp_rage" and target.hp / target.max_hp < 0.5)):
		trigger_counts.thorn_reflect += 1
		var reflect_power: float = target.passive_value() if target.passive_data.get("effect", "") == "low_hp_rage" else float(special_config.effects.thorn_reflect.power)
		if target.passive_data.get("effect", "") == "low_hp_rage": target.battle.note_passive(target.actor_id, target.passive_skill_id)
		source.take_damage(amount * reflect_power, target, false, {"kind": "effect", "allow_triggers": false})

func on_heal(source, amount: float) -> void:
	if is_instance_valid(source):
		combat_stats.record_heal(source.actor_id, amount)

func on_skill(source) -> void:
	combat_stats.record_skill(source.actor_id)

func trigger_lightning(source, primary) -> void:
	var effect: Dictionary = special_config.effects.crit_lightning
	var key: String = source.actor_id + ":crit_lightning"
	if float(effect_cooldowns.get(key, 0)) > 0 or randf() > float(effect.chance):
		return
	effect_cooldowns[key] = float(effect.cooldown)
	trigger_counts.crit_lightning += 1
	primary.take_damage(source.attack * float(effect.power), source, false, {"kind": "effect", "allow_triggers": false})
	spawn_tracer(source.position, primary.position, Color("#FFE65A"))

func propagate_poison(dead_unit) -> void:
	if dead_unit.poison_depth >= int(special_config.effects.poison_spread.max_chain_depth):
		return
	var source_faction: String = dead_unit.poison_source.faction if is_instance_valid(dead_unit.poison_source) else ("enemies" if dead_unit.faction == "heroes" else "heroes")
	var victims := enemies_near(dead_unit.position, source_faction, float(special_config.effects.poison_spread.range), int(special_config.effects.poison_spread.max_targets))
	trigger_counts.poison_spread += 1
	for victim in victims:
		victim.apply_poison(dead_unit.poison_damage, 4.0, dead_unit.poison_source, dead_unit.poison_depth + 1)

func stats_snapshot() -> Dictionary:
	return combat_stats.snapshot(elapsed)

func note_effect(id: String) -> void:
	trigger_counts[id] = int(trigger_counts.get(id, 0)) + 1

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
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = color
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)

func spawn_ring(at: Vector2, color: Color) -> void:
	var ring = EffectRingScript.new()
	ring.position = at
	ring.tint = color
	add_child(ring)

func restart() -> void:
	get_tree().reload_current_scene()

