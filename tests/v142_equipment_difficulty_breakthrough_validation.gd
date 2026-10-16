extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")

var battle
var failures: Array[String] = []
var remote_breakthrough_checks := 0
var remote_breakthrough_worlds: Dictionary = {}

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	_validate_equipment_scoring()
	_validate_difficulty_and_world_scaling()
	_validate_migration()
	_validate_breakthrough_health()
	battle.clear_combatants(); battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V142_EQUIPMENT_DIFFICULTY_BREAKTHROUGH_PASS scoring=physical/elemental world_hp=0.80 world_def=0.80 rift=1.00 difficulty_base=4.4 migration=v3 remote_breakthrough=75%% checks=%d worlds=%d" % [remote_breakthrough_checks, remote_breakthrough_worlds.size()])
		quit(0)
		return
	for failure in failures: push_error("V142_EQUIPMENT_DIFFICULTY_BREAKTHROUGH_FAIL: " + failure)
	quit(1)

func close(actual: float, expected: float, label: String, tolerance := 0.0001) -> void:
	if absf(actual - expected) > tolerance: failures.append("%s: %.6f != %.6f" % [label, actual, expected])

func score_item(instance_id: String, physical: float, elemental: float) -> Dictionary:
	return {"instance_id":instance_id,"name":instance_id,"quality_rank":4,"slot":"ring_1","compatible_slots":["ring_1","ring_2"],"base_stats":{"physical_damage":physical,"elemental_damage":elemental},"affixes":[],"world_affix":{},"locked":false}

func _validate_equipment_scoring() -> void:
	var inventory = InventoryManagerScript.new()
	inventory.setup(battle.equipment_config, battle.actors)
	var physical := score_item("physical_ring", 0.20, 0.0)
	var physical_two := score_item("physical_ring_two", 0.15, 0.0)
	var elemental := score_item("elemental_ring", 0.0, 0.20)
	var elemental_two := score_item("elemental_ring_two", 0.0, 0.15)
	if inventory.item_score(physical, "ranged_dps", {"basic_damage_type":"physical"}) <= 0.0: failures.append("物理职业未计入物理增伤")
	close(inventory.item_score(elemental, "ranged_dps", {"basic_damage_type":"physical"}), 0.0, "物理职业错误计入元素增伤")
	if inventory.item_score(elemental, "ranged_dps", {"basic_damage_type":"elemental"}) <= 0.0: failures.append("元素职业未计入元素增伤")
	close(inventory.item_score(physical, "ranged_dps", {"basic_damage_type":"elemental"}), 0.0, "元素职业错误计入物理增伤")
	close(inventory.item_score(physical, "healer", {"basic_damage_type":"none"}), 0.0, "治疗职业错误计入物理增伤")
	close(inventory.item_score(elemental, "healer", {"basic_damage_type":"none"}), 0.0, "治疗职业错误计入元素增伤")
	inventory.items = [physical, physical_two, elemental, elemental_two]
	inventory.ensure_equipment_layout()
	var huang_choices := inventory.optimize_candidates("huang_zhong", 0, 2, "ranged_dps")
	var zhou_choices := inventory.optimize_candidates("zhou_yu", 0, 2, "ranged_dps")
	if huang_choices.size() != 2: failures.append("物理远程双戒指优化未填满两槽")
	if zhou_choices.size() != 2: failures.append("元素远程双戒指优化未填满两槽")
	for choice in huang_choices:
		if not str(choice.instance_id).begins_with("physical_ring"): failures.append("物理远程一键优化选择了无关元素增伤")
	for choice in zhou_choices:
		if not str(choice.instance_id).begins_with("elemental_ring"): failures.append("元素远程一键优化选择了无关物理增伤")
	if not huang_choices.is_empty():
		var preview_gain := float(huang_choices[0].pair_gain)
		if inventory.apply_optimization("huang_zhong", huang_choices) != huang_choices.size(): failures.append("物理远程双戒指优化方案未完整应用")
		var applied_score := 0.0
		for slot in ["ring_1", "ring_2"]:
			applied_score += inventory.item_score(inventory.get_equipped_item("huang_zhong", slot), "ranged_dps", huang_choices[0].scoring_context)
		close(applied_score, preview_gain, "双戒指优化预览与实际评分不一致")
	inventory.free()

func _spawn_scaled_sample(rift: bool) -> Dictionary:
	battle.clear_combatants()
	battle.active_rift_context = {"world":"three_kingdoms","floor":30} if rift else {}
	var unit = battle.spawn_unit("yellow_turban", "enemies", Vector2(400, 260), {"max_hp":1000.0,"attack":500.0,"defense":100.0})
	return {"health":unit.max_hp,"attack":unit.attack,"defense":unit.defense,"unit":unit}

func _validate_difficulty_and_world_scaling() -> void:
	for coefficient in [0.2, 0.5, 1.0, 2.0, 3.0]:
		var profile: Dictionary = battle.custom_difficulty_profile(coefficient)
		close(float(profile.equivalent_old_coefficient), coefficient * 4.4, "旧版等价值 %.1f" % coefficient)
		close(float(profile.health), pow(coefficient * 4.4, 0.55), "生命曲线 %.1f" % coefficient)
		close(float(profile.attack), pow(coefficient * 4.4, 0.35), "攻击曲线 %.1f" % coefficient)
		close(float(profile.defense), pow(coefficient * 4.4, 0.18), "防御曲线 %.1f" % coefficient)
	battle.progression.combat_difficulty = 1.0
	var world := _spawn_scaled_sample(false)
	var hp_once := float(world.health); var defense_once := float(world.defense)
	battle.apply_world_enemy_adjustment(world.unit)
	close(float(world.unit.max_hp), hp_once, "世界生命重复削弱")
	close(float(world.unit.defense), defense_once, "世界防御重复削弱")
	var rift := _spawn_scaled_sample(true)
	close(float(world.health) / float(rift.health), 0.80, "大世界生命比例")
	close(float(world.defense) / float(rift.defense), 0.80, "大世界防御比例")
	close(float(world.attack) / float(rift.attack), 1.0, "大世界攻击不应削弱")
	var rift_summon := _spawn_scaled_sample(true)
	close(float(rift_summon.health), float(rift.health), "秘境召唤物生命被削弱")
	close(float(rift_summon.defense), float(rift.defense), "秘境召唤物防御被削弱")

func _validate_migration() -> void:
	var old_v2 = ProgressionManagerScript.new()
	old_v2.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":2,"combat_difficulty":1.0,"transaction_log":[]})
	close(old_v2.combat_difficulty, 2.5 / 4.4, "v2难度迁移保留精度")
	if old_v2.difficulty_migration_record.is_empty(): failures.append("难度迁移未保留旧记录")
	var count: int = old_v2.transaction_log.size()
	var reloaded = ProgressionManagerScript.new()
	reloaded.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":3,"combat_difficulty":old_v2.combat_difficulty,"difficulty_migration_record":old_v2.difficulty_migration_record,"transaction_log":old_v2.transaction_log})
	close(reloaded.combat_difficulty, 2.5 / 4.4, "v3难度重复加载")
	if reloaded.transaction_log.size() != count: failures.append("难度迁移重复执行")
	var legacy = ProgressionManagerScript.new(); legacy.apply_payload({"version":"0.8","team_progression_version":1,"combat_difficulty":4.4,"transaction_log":[]})
	close(legacy.combat_difficulty, 1.0, "原始旧4.4迁移")
	old_v2.free(); reloaded.free(); legacy.free()

func _validate_breakthrough_health() -> void:
	for actor_id_variant in ProgressionManagerScript.ALL_HERO_IDS:
		var actor_id_all := str(actor_id_variant)
		var actor_data: Dictionary = battle.actors.get(actor_id_all, {})
		if actor_data.is_empty() or not battle._is_remote_breakthrough_actor(actor_data):
			continue
		var native_all: int = battle.native_world_tier(actor_id_all)
		close(float(battle.breakthrough_base_stats(actor_id_all, native_all).max_hp), float(actor_data.max_hp), "未破限生命不变 " + actor_id_all, 0.01)
		if native_all >= 10:
			continue
		var target_all := native_all + 1
		var stats_all: Dictionary = battle.breakthrough_base_stats(actor_id_all, target_all)
		var tank_reference_all: float = battle.breakthrough_tank_health_reference(target_all)
		close(float(stats_all.max_hp), maxf(float(actor_data.max_hp), tank_reference_all * 0.75), "全远程破限75% " + actor_id_all, 0.01)
		remote_breakthrough_checks += 1
		remote_breakthrough_worlds[str(actor_data.get("world", ""))] = true
	var representatives := ["huang_zhong", "zhou_yu", "diao_chan", "liu_bei"]
	for actor_id in representatives:
		var native: int = battle.native_world_tier(actor_id)
		var target_tier: int = native + 1
		var stats: Dictionary = battle.breakthrough_base_stats(actor_id, target_tier)
		var tank_reference: float = battle.breakthrough_tank_health_reference(target_tier)
		var original_hp := float(battle.actors[actor_id].max_hp)
		close(float(stats.max_hp), maxf(original_hp, tank_reference * 0.75), "远程破限75% " + actor_id, 0.01)
	var tank_native: int = battle.native_world_tier("zhang_fei")
	var tank_stats: Dictionary = battle.breakthrough_base_stats("zhang_fei", tank_native + 1)
	var tank_target: Dictionary = battle._tier_role_target(tank_native + 1, "tank")
	close(float(tank_stats.max_hp), maxf(float(battle.actors.zhang_fei.max_hp), float(tank_target.max_hp)), "坦克破限生命不变", 0.01)
	var melee_stats: Dictionary = battle.breakthrough_base_stats("guan_yu", battle.native_world_tier("guan_yu") + 1)
	var melee_target: Dictionary = battle._tier_role_target(2, battle._breakthrough_role(battle.actors.guan_yu))
	close(float(melee_stats.max_hp), maxf(float(battle.actors.guan_yu.max_hp), float(melee_target.max_hp)), "近战破限生命不变", 0.01)
	var actor_id := "huang_zhong"
	var target_tier: int = battle.native_world_tier(actor_id) + 1
	battle.progression.actor_breakthrough_tiers[actor_id] = target_tier
	var preview: Dictionary = battle.breakthrough_preview(actor_id)
	var unit = battle.spawn_unit(actor_id, "heroes", Vector2(250, 250))
	var level_growth := 1.0 + float(battle.progression.actor_level(actor_id) - 1) * 0.08
	close(float(preview.current_stats.max_hp) * level_growth, float(unit.base_max_hp), "破限预览与战斗基础生命", 0.01)
