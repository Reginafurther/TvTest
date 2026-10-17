extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")

var battle
var failures: Array[String] = []
var combo_levels: Array[float] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	_validate_skill_data()
	_validate_zhao_combo()
	_validate_guan_thresholds()
	_validate_difficulty_profiles()
	_validate_enemy_panels()
	_validate_difficulty_migration()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V146_SKILL_DIFFICULTY_ART_PASS combo=%s guan_armor_break=40%% guan_threshold=70%% mapping=1:3 stage1_fixed=true world_hp_def=75%% boss_attack=130%% rift_exempt=true" % str(combo_levels))
		quit(0)
		return
	for failure in failures:
		push_error("V146_SKILL_DIFFICULTY_ART_FAIL: " + failure)
	quit(1)

func close(actual: float, expected: float, label: String, tolerance := 0.001) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %.6f != %.6f" % [label, actual, expected])

func _validate_skill_data() -> void:
	var combo: Dictionary = battle.passives_config.combo_mastery
	for level in range(1, 11):
		var value := float(combo.value) + float(combo.per_level) * (level - 1)
		combo_levels.append(snappedf(value, 0.0001))
		close(value, 0.55 + (3.0 - 0.55) * float(level - 1) / 9.0, "龙胆连击Lv%d" % level)
	close(combo_levels[0], 0.55, "龙胆连击1级")
	close(combo_levels[9], 3.0, "龙胆连击10级")
	var active: Dictionary = battle.skills.green_dragon_slash
	close(float(active.armor_break), 0.40, "青龙偃月斩破甲")
	close(float(active.duration), 5.0, "青龙偃月斩破甲持续")
	close(float(active.execute_threshold), 0.70, "青龙偃月斩血线")
	close(float(active.power) * (1.0 + float(active.power_per_level) * 9.0), 3.3696, "青龙偃月斩10级倍率")
	var passive: Dictionary = battle.passives_config.executioner
	close(float(passive.threshold), 0.70, "武圣斩将血线")
	close(float(passive.value) + float(passive.per_level) * 9.0, 0.445, "武圣斩将10级倍率")
	var ui = CharacterUIScript.new()
	ui.battle = battle
	var combo_level_nine: String = ui.skill_numeric_description(combo, 9, "passive", true)
	var combo_level_ten: String = ui.skill_numeric_description(combo, 10, "passive", true)
	if "升级至Lv.10：272.8% → 300.0%" not in combo_level_nine or "当前实际倍率：300.0%" not in combo_level_ten:
		failures.append("角色面板未同步龙胆连击当前/下一等级倍率")
	var guan_active_panel: String = ui.skill_numeric_description(active, 1, "active", true)
	var guan_passive_panel: String = ui.skill_numeric_description(passive, 1, "passive", true)
	if "降低防御：40.0%" not in guan_active_panel or "低血量触发线：≤70.0%" not in guan_active_panel:
		failures.append("角色面板未同步青龙偃月斩破甲/血线")
	if "触发血线：≤70.0%" not in guan_passive_panel:
		failures.append("角色面板未同步武圣斩将血线")
	ui.free()

func _fresh_combat() -> void:
	battle.clear_combatants()
	battle.active_rift_context = {}
	battle.damage_trace.clear()
	battle.passive_trigger_counts.clear()

func _enemy(actor_id: String, hp_value := 10000.0):
	return battle.spawn_unit("yellow_turban", "enemies", Vector2(280, 250), {"name":actor_id,"max_hp":hp_value,"attack":10.0,"defense":0.0,"enemy_type":"normal"})

func _validate_zhao_combo() -> void:
	_fresh_combat()
	var zhao = battle.spawn_unit("zhao_yun", "heroes", Vector2(220, 250))
	var first = _enemy("combo_first", 100000.0)
	var switched = _enemy("combo_switched", 100000.0)
	zhao.attack = 100.0
	zhao.crit_chance = 0.0
	zhao.passive_skill_level = 10
	zhao.target = first
	seed(14601); zhao.basic_attack()
	zhao.target = first
	seed(14602); zhao.basic_attack()
	zhao.target = switched
	seed(14603); zhao.basic_attack()
	var passive_rows: Array = battle.damage_trace.filter(func(row): return str(row.get("attack_type", "")) == "passive")
	if passive_rows.size() != 1:
		failures.append("龙胆连击换目标后的第3次普攻没有且仅触发一次")
	else:
		close(float(passive_rows[0].raw), 300.0, "龙胆连击10级追加伤害")
	if int(battle.passive_trigger_counts.get("zhao_yun:combo_mastery", 0)) != 1:
		failures.append("龙胆连击触发统计错误")

func _active_damage_at_ratio(ratio: float) -> Dictionary:
	_fresh_combat()
	var guan = battle.spawn_unit("guan_yu", "heroes", Vector2(220, 250))
	var enemy = _enemy("guan_active_target", 100000.0)
	guan.attack = 100.0
	guan.active_skill_level = 1
	guan.passive_data = {}
	guan.passive_skill_id = ""
	guan.target = enemy
	enemy.hp = enemy.max_hp * ratio
	var before: float = enemy.hp
	if not guan.try_use_skill(): failures.append("青龙偃月斩未释放")
	return {"damage":before - enemy.hp,"armor_break":enemy.armor_break_power,"duration":enemy.armor_break_time}

func _basic_damage_at_ratio(ratio: float) -> float:
	_fresh_combat()
	var guan = battle.spawn_unit("guan_yu", "heroes", Vector2(220, 250))
	var enemy = _enemy("guan_passive_target", 100000.0)
	guan.attack = 100.0
	guan.crit_chance = 0.0
	guan.passive_skill_level = 1
	guan.target = enemy
	enemy.hp = enemy.max_hp * ratio
	seed(14604)
	guan.basic_attack()
	var rows: Array = battle.damage_trace.filter(func(row): return str(row.get("attack_type", "")) == "basic")
	return float(rows[-1].raw) if not rows.is_empty() else 0.0

func _validate_guan_thresholds() -> void:
	var active_equal := _active_damage_at_ratio(0.70)
	var active_above := _active_damage_at_ratio(0.7001)
	close(float(active_equal.armor_break), 0.40, "70%时主动破甲")
	close(float(active_equal.duration), 5.0, "主动破甲持续时间")
	close(float(active_equal.damage) / float(active_above.damage), 1.55, "主动70%边界增伤", 0.02)
	var passive_equal := _basic_damage_at_ratio(0.70)
	var passive_above := _basic_damage_at_ratio(0.7001)
	close(passive_equal / passive_above, 1.22, "被动70%边界增伤", 0.02)

func _validate_difficulty_profiles() -> void:
	for coefficient in [1.0, 1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]:
		var profile: Dictionary = battle.custom_difficulty_profile(coefficient)
		close(float(profile.previous_ui_coefficient), coefficient * 3.0, "新版%.1f对应修改前难度" % coefficient)
		close(float(profile.equivalent_old_coefficient), coefficient * 13.2, "新版%.1f曲线输入" % coefficient)
	close(float(battle.custom_difficulty_profile(8.0).equivalent_old_coefficient), 105.6, "难度8.0未被旧上限截断")

func _panel(map_id: String, coefficient: float, boss: bool, rift: bool) -> Dictionary:
	_fresh_combat()
	battle.current_map_id = map_id
	battle.progression.combat_difficulty = coefficient
	battle.active_rift_context = {"world":"three_kingdoms","floor":1} if rift else {}
	var overrides := {"max_hp":1000.0,"attack":500.0,"defense":100.0,"enemy_type":"boss" if boss else "normal"}
	if boss: overrides["boss_id"] = "panel_test"
	var unit = battle.spawn_unit("yellow_turban", "enemies", Vector2(300, 250), overrides)
	return {"health":unit.max_hp,"attack":unit.attack,"defense":unit.defense,"fixed":unit.get_meta("first_stage_difficulty_fixed", false)}

func _validate_enemy_panels() -> void:
	var stage1_low := _panel("hulao_pass", 1.0, false, false)
	var stage1_high := _panel("hulao_pass", 8.0, false, false)
	for stat in ["health", "attack", "defense"]: close(float(stage1_low[stat]), float(stage1_high[stat]), "第一关固定面板 " + stat)
	if not bool(stage1_low.fixed) or not bool(stage1_high.fixed): failures.append("第一关未标记固定难度")
	var stage2_low := _panel("guandu_road", 1.0, false, false)
	var stage2_high := _panel("guandu_road", 8.0, false, false)
	if float(stage2_high.health) <= float(stage2_low.health) or float(stage2_high.attack) <= float(stage2_low.attack) or float(stage2_high.defense) <= float(stage2_low.defense): failures.append("第二关未随难度增长")
	var world_normal := _panel("guandu_road", 1.0, false, false)
	var world_boss := _panel("guandu_road", 1.0, true, false)
	var rift_normal := _panel("guandu_road", 1.0, false, true)
	var rift_boss := _panel("guandu_road", 1.0, true, true)
	close(float(world_normal.health) / float(rift_normal.health), 0.75, "世界生命75%")
	close(float(world_normal.defense) / float(rift_normal.defense), 0.75, "世界防御75%")
	close(float(world_normal.attack) / float(rift_normal.attack), 1.0, "世界普通怪攻击不变")
	close(float(world_boss.attack) / float(world_normal.attack), 1.30, "世界Boss攻击30%")
	close(float(rift_boss.attack) / float(rift_normal.attack), 1.0, "秘境Boss不应用30%")
	close(float(rift_boss.health), float(rift_normal.health), "秘境不应用世界生命系数")
	close(float(rift_boss.defense), float(rift_normal.defense), "秘境不应用世界防御系数")

func _validate_difficulty_migration() -> void:
	var migrated = ProgressionManagerScript.new()
	migrated.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":3,"combat_difficulty":3.0,"transaction_log":[]})
	close(migrated.combat_difficulty, 1.0, "旧3.0迁移新版1.0")
	var transaction_count: int = migrated.transaction_log.size()
	var reloaded = ProgressionManagerScript.new()
	reloaded.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":4,"combat_difficulty":migrated.combat_difficulty,"difficulty_migration_record":migrated.difficulty_migration_record,"transaction_log":migrated.transaction_log})
	close(reloaded.combat_difficulty, 1.0, "难度迁移不重复")
	if reloaded.transaction_log.size() != transaction_count: failures.append("难度迁移日志重复")
	var low = ProgressionManagerScript.new(); low.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":3,"combat_difficulty":1.0,"transaction_log":[]})
	close(low.combat_difficulty, 1.0, "低于新范围按1.0处理")
	if not bool(low.difficulty_migration_record.get("clamped", false)): failures.append("低难度迁移未记录截断")
	var high = ProgressionManagerScript.new(); high.apply_payload({"version":"1.0","team_progression_version":1,"difficulty_config_version":3,"combat_difficulty":30.0,"transaction_log":[]})
	close(high.combat_difficulty, 8.0, "高于新范围按8.0处理")
	if not bool(high.difficulty_migration_record.get("clamped", false)): failures.append("高难度迁移未记录截断")
	migrated.free(); reloaded.free(); low.free(); high.free()
