extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")

class FakeBattle extends Node:
	var heroes: Array = []
	var enemies: Array = []
	var general_skills_config: Dictionary = {}
	var suppress_combat_visuals := true
	var is_paused := false
	var active_rift_context: Dictionary = {}
	var damage_actor_ids: Array[String] = []
	var heal_actor_ids: Array[String] = []
	func record_damage_resolution(_source, _target, _result: Dictionary, _context: Dictionary) -> void: pass
	func on_damage(source, _target, _amount: float, context: Dictionary) -> void:
		damage_actor_ids.append(str(source.actor_id) if is_instance_valid(source) else str(context.get("source_actor_id", "")))
	func on_heal(source, _amount: float, snapshot: Dictionary = {}) -> void:
		heal_actor_ids.append(str(source.actor_id) if is_instance_valid(source) else str(snapshot.get("actor_id", "")))
	func note_passive(_actor_id: String, _passive_id: String) -> void: pass
	func select_combat_target(_unit): return null
	func enemies_near(_position: Vector2, _faction: String, _range: float, _limit: int) -> Array: return []
	func on_skill(_source) -> void: pass

var battle
var failures: Array[String] = []
var save_path := "user://v09_stage3_lifecycle_progress_test.json"

func _initialize() -> void:
	await _validate_freed_status_sources()
	await _validate_stage3_boss_lifecycle()
	if failures.is_empty():
		print("V09_STAGE3_LIFECYCLE_VALIDATION_PASS burn_10s=true lethal_tick=true poison=true hot=true share=true repeats=3 unlock4=true auto_push=true")
		quit(0)
		return
	for failure in failures:
		push_error("V09_STAGE3_LIFECYCLE_VALIDATION_FAIL: " + failure)
	quit(1)

func _fake_unit(owner: FakeBattle, id: String, faction: String, hp_value: float = 1000.0):
	var unit = BattleUnitScript.new()
	unit.battle = owner
	unit.actor_id = id
	unit.actor_data = {"name":id, "basic_damage_type":"elemental"}
	unit.faction = faction
	unit.max_hp = hp_value
	unit.hp = hp_value
	unit.attack = 20.0
	root.add_child(unit)
	return unit

func _validate_freed_status_sources() -> void:
	var fake := FakeBattle.new()
	root.add_child(fake)
	var source = _fake_unit(fake, "freed_caster", "enemies")
	source.elemental_damage = 0.25
	source.final_damage = 0.10
	var burned = _fake_unit(fake, "burned_hero", "heroes", 10000.0)
	burned.apply_burn(10.0, 4.0, source)
	var snapshot: Dictionary = burned.burn_source_snapshot.duplicate(true)
	source.free()
	for second in range(10):
		burned._physics_process(1.0)
	if burned.dead or burned.hp >= burned.max_hp or burned.burn_time > 0.0:
		failures.append("来源释放后燃烧10秒生命周期未安全结束")
	if fake.damage_actor_ids.is_empty() or fake.damage_actor_ids[0] != "freed_caster":
		failures.append("失效燃烧来源未保留伤害统计归属")
	if not is_equal_approx(float(snapshot.elemental_damage), 0.25) or not is_equal_approx(float(snapshot.final_damage), 0.10):
		failures.append("持续伤害来源快照没有保存施加时增伤")

	var lethal_source = _fake_unit(fake, "lethal_boss", "enemies")
	var lethal = _fake_unit(fake, "lethal_hero", "heroes", 40.0)
	lethal.apply_burn(10.0, 4.0, lethal_source)
	lethal_source.free()
	for second in range(4): lethal._physics_process(1.0)
	if not lethal.dead:
		failures.append("失效来源的最后一跳燃烧未正常结算角色死亡")

	var status_source = _fake_unit(fake, "status_caster", "heroes")
	var poisoned = _fake_unit(fake, "poison_target", "enemies")
	var healed = _fake_unit(fake, "hot_target", "heroes")
	healed.hp = 100.0
	poisoned.apply_poison(8.0, 2.0, status_source, 0)
	healed.apply_hot(40.0, 2.0, status_source)
	status_source.free()
	for second in range(3):
		poisoned._physics_process(1.0)
		healed._physics_process(1.0)
	if poisoned.hp >= poisoned.max_hp or healed.hp <= 100.0:
		failures.append("中毒或持续治疗来源释放后未安全结算")
	if fake.heal_actor_ids.is_empty() or fake.heal_actor_ids[0] != "status_caster":
		failures.append("失效持续治疗来源未保留统计归属")

	var protector = _fake_unit(fake, "protector", "heroes")
	var protected = _fake_unit(fake, "protected", "heroes")
	protected.apply_damage_share(protector, 0.4, 5.0)
	protector.free()
	protected.take_damage(50.0, null, false, {"kind":"effect", "damage_type":"none", "allow_triggers":false})
	if protected.damage_share_time > 0.0 or protected.hp != protected.max_hp - 50.0:
		failures.append("伤害分担来源释放后未自动失效或错误吞伤")

	for unit in [burned, lethal, poisoned, healed, protected]:
		if is_instance_valid(unit): unit.queue_free()
	fake.queue_free()
	await process_frame

func _prepare_stage3() -> void:
	battle.clear_combatants()
	battle.current_map_id = "bowang_slope"
	battle.wave = 3
	battle.stage_cleared = false
	battle.stage_resolution_started = false
	var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(730, 260))
	hero.max_hp = 100000.0
	hero.hp = hero.max_hp
	battle.spawn_wave()

func _validate_stage3_boss_lifecycle() -> void:
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.progression.save_path = save_path
	battle.is_paused = true
	battle.progression.completed_stages = [1, 2]
	battle.progression.ensure_world_layout()
	var first_clear_gold := -1
	for cycle in range(3):
		_prepare_stage3()
		var hero = battle.heroes[0]
		var boss = battle.enemies[0]
		if boss._name() != "高顺" or str(boss.actor_data.get("boss_mechanic", "")) != "burning_aura":
			failures.append("第三关没有生成高顺燃烧光环Boss")
			break
		boss.on_boss_skill_cast()
		if hero.burn_time <= 0.0:
			failures.append("高顺燃烧光环没有施加燃烧")
		boss.dead = true
		battle._on_unit_died(boss)
		boss.free()
		battle.is_paused = false
		for second in range(10): hero._physics_process(1.0)
		battle.is_paused = true
		if not battle.stage_cleared or not battle.stage_boss_defeated:
			failures.append("第%d次第三关Boss死亡后未正常结算" % (cycle + 1))
		if battle.current_stage_wave() != 3 or battle.wave != 4:
			failures.append("第%d次第三关出现超过3/3波的内部状态" % (cycle + 1))
		var enemy_count: int = battle.enemies.size()
		battle.spawn_wave()
		if battle.enemies.size() != enemy_count:
			failures.append("第%d次第三关通关后仍生成额外波次" % (cycle + 1))
		if cycle == 0:
			first_clear_gold = battle.progression.gold
			if not battle.progression.is_stage_complete(3) or not battle.progression.can_enter_stage(4):
				failures.append("第三关首通后没有记录完成并解锁第四关")
		else:
			if battle.progression.completed_stages.count(3) != 1:
				failures.append("第三关重复挂机重复写入首通记录")
	if first_clear_gold < 0:
		failures.append("第三关首通奖励未执行")

	_prepare_stage3()
	battle.progression.auto_push = true
	var push_boss = battle.enemies[0]
	push_boss.dead = true
	battle._on_unit_died(push_boss)
	battle.continue_after_stage()
	if int(battle.worlds_config.maps.get(battle.current_map_id, {}).get("global_stage", 0)) != 4:
		failures.append("开启自动推关后第三关未进入第四关")

	_prepare_stage3()
	battle.progression.auto_push = false
	var repeat_boss = battle.enemies[0]
	repeat_boss.dead = true
	battle._on_unit_died(repeat_boss)
	battle.continue_after_stage()
	if battle.current_map_id != "bowang_slope":
		failures.append("关闭自动推关后没有留在第三关重复挂机")

	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if FileAccess.file_exists(save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
