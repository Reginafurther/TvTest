extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.progression.save_path = "user://v081_mainline_wave_progress_test.json"
	battle.is_paused = true
	_validate_all_stage_pools()
	_validate_stage_23_regular_wave()
	_validate_stage_23_completion_orders()
	_validate_stage_29_unlock()
	_validate_reward_identity()
	battle.clear_combatants()
	if FileAccess.file_exists(battle.progression.save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(battle.progression.save_path))
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V081_MAINLINE_WAVE_VALIDATION_PASS stages=40 late_world_pools=20 stage23_orders=3 stage29_to_30=true max_waves=3 rewards=true")
		quit(0)
		return
	for failure in failures:
		push_error("V081_MAINLINE_WAVE_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_all_stage_pools() -> void:
	var seen_stages: Dictionary = {}
	var late_stage_count := 0
	for map_id in battle.worlds_config.maps:
		var map_data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(map_data.get("global_stage", 0))
		seen_stages[stage] = true
		var pool: Array[String] = battle.valid_mainline_enemy_pool(map_data)
		if pool.size() != map_data.get("enemy_pool", []).size():
			failures.append("第%d关普通池仍包含Boss或无效模板" % stage)
		for enemy_id in pool:
			var actor: Dictionary = battle.actors.get(enemy_id, {})
			if str(actor.get("enemy_type", "normal")) == "boss" or actor.has("boss_id"):
				failures.append("第%d关普通池单位仍有Boss身份：%s" % [stage, enemy_id])
		if stage >= 21:
			late_stage_count += 1
			if pool.is_empty(): failures.append("第%d关没有普通怪" % stage)
	if seen_stages.size() != 40 or late_stage_count != 20:
		failures.append("主线关卡数量不是1—40")
	# Exercise both a regular wave and the configured final wave for every stage.
	for map_id in battle.worlds_config.maps:
		var map_data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(map_data.get("global_stage", 0))
		battle.clear_combatants()
		battle.current_map_id = str(map_id)
		battle.wave = 1
		battle.stage_cleared = false
		battle.spawn_wave()
		if battle.enemies.size() != 4:
			failures.append("第%d关普通波生成数量错误" % stage)
		for enemy in battle.enemies:
			if enemy.enemy_type == "boss" or enemy.actor_data.has("boss_id"):
				failures.append("第%d关实际普通波生成Boss身份单位" % stage)
		battle.clear_combatants()
		battle.current_map_id = str(map_id)
		battle.wave = int(map_data.get("waves_to_clear", 3))
		battle.stage_cleared = false
		battle.spawn_wave()
		if battle.enemies.size() != 1 or battle.enemies[0].enemy_type != "boss" or not bool(battle.enemies[0].actor_data.get("stage_boss", false)):
			failures.append("第%d关最终波未生成唯一的真实Boss" % stage)
	battle.clear_combatants()

func _prepare_stage_23() -> void:
	battle.clear_combatants()
	battle.current_map_id = "tokyo_paradise"
	battle.wave = 3
	battle.stage_cleared = false
	battle.progression.completed_stages = []
	for stage in range(1, 23): battle.progression.completed_stages.append(stage)
	battle.progression.ensure_world_layout()
	battle.spawn_wave()

func _validate_stage_23_regular_wave() -> void:
	battle.clear_combatants()
	battle.current_map_id = "tokyo_paradise"
	battle.wave = 1
	battle.stage_cleared = false
	battle.spawn_wave()
	if battle.wave != 2 or battle.enemies.size() != 4:
		failures.append("第23关第一波生成数量或计数错误")
	for enemy in battle.enemies:
		if enemy.enemy_type == "boss" or enemy.actor_data.has("boss_id"):
			failures.append("第23关普通怪带有Boss身份")
	battle.clear_combatants()

func _validate_stage_23_completion_orders() -> void:
	# Boss未召唤就死亡。
	_prepare_stage_23()
	var boss = battle.enemies[0]
	if boss._name() != "王将" or not bool(boss.actor_data.get("stage_boss", false)):
		failures.append("第23关最终波没有生成王将")
	battle._on_unit_died(boss)
	if not battle.stage_cleared or not battle.stage_boss_defeated:
		failures.append("王将无召唤物死亡时未通关")
	if battle.current_stage_wave() != 3:
		failures.append("第23关显示波次不是3/3")
	var kills_after_boss: int = battle.kills
	battle._on_unit_died(boss)
	if battle.kills != kills_after_boss:
		failures.append("重复死亡回调重复结算奖励")
	var count_before: int = battle.enemies.size()
	battle.spawn_wave()
	if battle.enemies.size() != count_before:
		failures.append("通关后仍生成第四波")

	# Boss先死，召唤物后死。
	_prepare_stage_23()
	boss = battle.enemies[0]
	boss.summon_boss_minion(false)
	var summon = battle.enemies.back()
	if summon.actor_id != "dragon_deadpool" or summon.enemy_type != "normal" or summon.actor_data.has("boss_id"):
		failures.append("王将召唤物不是龙族普通怪身份")
	battle._on_unit_died(boss)
	if battle.stage_cleared or not battle.stage_boss_defeated:
		failures.append("王将先死时Boss状态未被持久记录")
	battle._on_unit_died(summon)
	if not battle.stage_cleared:
		failures.append("王将先死、召唤物后死时未通关")
	battle.spawn_wave()
	if not battle.enemies.is_empty():
		failures.append("召唤物清理后错误生成第四波")

	# 召唤物先死，Boss后死。
	_prepare_stage_23()
	boss = battle.enemies[0]
	boss.summon_boss_minion(false)
	summon = battle.enemies.back()
	battle._on_unit_died(summon)
	if battle.stage_cleared:
		failures.append("王将存活时错误提前通关")
	battle._on_unit_died(boss)
	if not battle.stage_cleared:
		failures.append("召唤物先死、王将后死时未通关")

	# 即使状态异常落在next-wave=4，也只能停住，不能生成4/3波。
	_prepare_stage_23()
	battle.enemies.clear()
	battle.stage_boss_defeated = false
	battle.spawn_wave()
	if not battle.enemies.is_empty() or battle.wave != 4:
		failures.append("第四波防线仍允许额外刷怪")

func _validate_reward_identity() -> void:
	_prepare_stage_23()
	var boss = battle.enemies[0]
	var summon = battle.spawn_unit("zubat", "enemies", Vector2(820, 220))
	# A stale metadata field must not elevate a normal combat unit to Boss rewards.
	summon.actor_data["boss_id"] = "stale_template_metadata"
	summon.enemy_type = "normal"
	if not is_equal_approx(battle.skill_book_drop_chance(summon), 0.025):
		failures.append("普通怪仍因boss_id元数据获得Boss技能书保底")
	summon.enemy_type = "elite"
	if not is_equal_approx(battle.skill_book_drop_chance(summon), 0.14):
		failures.append("精英怪技能书概率分类错误")
	if not is_equal_approx(battle.skill_book_drop_chance(boss), 1.0):
		failures.append("真正Boss丢失技能书保底")
	var normal_xp: int = battle.progression.experience_for_kill(23, "normal", 23)
	var elite_xp: int = battle.progression.experience_for_kill(23, "elite", 23)
	var boss_xp: int = battle.progression.experience_for_kill(23, "boss", 23)
	if not (normal_xp < elite_xp and elite_xp < boss_xp):
		failures.append("普通/精英/Boss经验分类错误")

func _validate_stage_29_unlock() -> void:
	battle.clear_combatants()
	battle.current_map_id = "white_king_relic"
	battle.wave = 3
	battle.stage_cleared = false
	battle.progression.auto_push = false
	battle.progression.completed_stages = range(1, 29)
	battle.progression.ensure_world_layout()
	battle.spawn_wave()
	if battle.enemies.size() != 1 or battle.enemies[0]._name() != "白王":
		failures.append("第29关最终波未生成白王")
		return
	battle._on_unit_died(battle.enemies[0])
	if not battle.stage_cleared or not battle.progression.is_stage_complete(29) or not battle.progression.can_enter_stage(30):
		failures.append("第29关合法通关后未立即解锁第30关")
	if battle.current_map_id != "white_king_relic":
		failures.append("关闭自动推关时第29关通关后仍切换了地图")
