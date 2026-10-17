extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")

var battle
var failures: Array[String] = []
var exclusive_targeted := 0
var exclusive_exempt := 0
var remote_general := 0

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	_validate_catalog_ranges()
	_validate_exclusive_boundaries()
	_validate_general_boundaries()
	_validate_strategy_counts()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V102_ACTIVE_CAST_RANGE_PASS heroes=92 exclusive_targeted=%d exclusive_exempt=%d remote_general=%d cast_range=420 boundaries=400/450 strategy=true melee_effect_preserved=true" % [exclusive_targeted, exclusive_exempt, remote_general])
		quit(0)
		return
	for failure in failures: push_error("V102_ACTIVE_CAST_RANGE_FAIL: " + failure)
	quit(1)

func playable_actor_ids() -> Array[String]:
	var result: Array[String] = []
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if not actor.has("enemy_type") and actor.has("skill") and actor.has("passive_skill"):
			result.append(str(actor_id))
	return result

func unit_for(actor_id: String):
	var unit = BattleUnitScript.new()
	unit.actor_id = actor_id
	unit.actor_data = battle.actors[actor_id]
	unit.skill_data = battle.skills[str(unit.actor_data.skill)]
	unit.faction = "heroes"
	unit.battle = battle
	return unit

func _validate_catalog_ranges() -> void:
	var ids := playable_actor_ids()
	if ids.size() != 92: failures.append("可招募英雄数量不是92：%d" % ids.size())
	for actor_id in ids:
		var unit = unit_for(actor_id)
		if unit.exclusive_skill_requires_enemy_target() or unit.exclusive_skill_requires_ally_target():
			exclusive_targeted += 1
			if not is_equal_approx(unit.effective_cast_range(float(unit.skill_data.get("range", 180.0))), 420.0):
				failures.append("专属主动未统一420：%s" % actor_id)
		else:
			exclusive_exempt += 1
		unit.free()
	var probe = unit_for("zhao_yun")
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		if str(data.get("category", "")) != "active" or not probe.general_skill_is_remote(data): continue
		remote_general += 1
		if not is_equal_approx(probe.general_active_cast_range(data), 420.0):
			failures.append("远程通用主动未统一420：%s" % skill_id)
	if remote_general != 63: failures.append("远程/嘲讽通用主动覆盖数量变化：%d" % remote_general)
	probe.free()

func _fixture(actor_id: String, distance: float, enemy_id: String = "jy_bladesman") -> Dictionary:
	battle.clear_combatants()
	var hero = battle.spawn_unit(actor_id, "heroes", Vector2(300.0, 260.0))
	var ally = battle.spawn_unit("liu_bei" if actor_id != "liu_bei" else "zhao_yun", "heroes", Vector2(320.0, 280.0))
	var enemy = battle.spawn_unit(enemy_id, "enemies", hero.position + Vector2(distance, 0.0))
	hero.target = enemy
	ally.hp = ally.max_hp * 0.25
	hero.hp = hero.max_hp * 0.65
	enemy.hp = enemy.max_hp
	return {"hero":hero, "ally":ally, "enemy":enemy}

func _validate_exclusive_boundaries() -> void:
	battle.progression.active_strategy = "稳健"
	var fixture := _fixture("zhou_yu", 400.0)
	var hero = fixture.hero
	var enemy = fixture.enemy
	hero.skill_timer = 0.0
	if not battle.strategy_allows(hero) or not hero.try_auto_skills() or enemy.burn_time <= 0.0:
		failures.append("周瑜稳健策略在400距离未自动释放赤壁烈焰")

	fixture = _fixture("zhou_yu", 450.0)
	hero = fixture.hero; enemy = fixture.enemy; hero.skill_timer = 0.0
	if battle.strategy_allows(hero) or hero.try_use_skill() or enemy.burn_time > 0.0:
		failures.append("周瑜在450距离仍可释放目标型专属主动")

	fixture = _fixture("zhao_yun", 400.0)
	hero = fixture.hero; enemy = fixture.enemy; hero.skill_timer = 0.0
	var hp_before: float = enemy.hp
	if not battle.strategy_allows(hero): failures.append("近战专属主动在400距离未通过统一目标检测")
	if hero.try_use_skill() or enemy.hp < hp_before:
		failures.append("近战技能在400距离直接造成了近身伤害")

func _validate_general_boundaries() -> void:
	var fixture := _fixture("zhao_yun", 400.0)
	var hero = fixture.hero
	var enemy = fixture.enemy
	hero.general_active_timers["tk_flame_arrow"] = 0.0
	if not hero.try_use_general_skill("tk_flame_arrow") or enemy.hp >= enemy.max_hp:
		failures.append("远程通用主动在400距离未释放")

	fixture = _fixture("zhao_yun", 450.0)
	hero = fixture.hero; enemy = fixture.enemy
	hero.general_active_timers["tk_flame_arrow"] = 0.0
	if hero.try_use_general_skill("tk_flame_arrow") or enemy.hp < enemy.max_hp:
		failures.append("远程通用主动在450距离仍可释放")

func _validate_strategy_counts() -> void:
	var fixture := _fixture("zhou_yu", 400.0, "stage_guardian_tk")
	var hero = fixture.hero
	if not battle.strategy_allows(hero): failures.append("稳健策略错误拒绝420内单个Boss")
	battle.progression.active_strategy = "猛攻"
	if battle.strategy_allows(hero): failures.append("猛攻策略丢失原有2名敌人条件")
	battle.spawn_unit("jy_bladesman", "enemies", hero.position + Vector2(390.0, 30.0))
	if not battle.strategy_allows(hero): failures.append("猛攻策略未识别420内多个普通敌人")
	battle.progression.active_strategy = "稳健"
