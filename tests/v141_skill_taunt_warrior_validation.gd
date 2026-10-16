extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	_validate_skill_values()
	_validate_skill_behaviors()
	_validate_taunts()
	_validate_warrior_staging()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V141_SKILL_TAUNT_WARRIOR_PASS skills=18 taunt_range=420 taunt_cap=12 wave_reset=true warrior_follow=210")
		quit(0)
		return
	for failure in failures: push_error("V141_SKILL_TAUNT_WARRIOR_FAIL: " + failure)
	quit(1)

func close(actual: float, expected: float, label: String, tolerance := 0.001) -> void:
	if absf(actual - expected) > tolerance: failures.append("%s: %.6f != %.6f" % [label, actual, expected])

func active_value(data: Dictionary, level: int) -> float:
	return float(data.get("power", 0.0)) * (1.0 + float(data.get("power_per_level", 0.0)) * (level - 1))

func passive_value(data: Dictionary, level: int) -> float:
	return float(data.get("value", 0.0)) + float(data.get("per_level", 0.0)) * (level - 1)

func general_value(data: Dictionary, level: int) -> float:
	return float(data.get("power", 0.0)) + float(data.get("power_per_level", 0.0)) * (level - 1)

func _validate_skill_values() -> void:
	close(active_value(battle.skills.rest, 1), 0.33, "睡觉1级")
	close(active_value(battle.skills.rest, 10), 0.627, "睡觉10级")
	close(active_value(battle.skills.shell_guard, 10), 0.40, "缩壳守护10级")
	close(float(battle.skills.aura_sphere.armor_break) + float(battle.skills.aura_sphere.armor_break_per_level) * 9.0, 0.35, "波导弹10级破甲")
	close(passive_value(battle.passives_config.thick_fat, 10), 0.36, "厚脂生命")
	close(float(battle.passives_config.thick_fat.regen_ratio) + float(battle.passives_config.thick_fat.regen_ratio_per_level) * 9.0, 0.04, "厚脂恢复")
	close(passive_value(battle.passives_config.poison_master, 10), 2.0, "剧毒蔓延伤害")
	close(float(battle.passives_config.poison_master.duration_bonus) + float(battle.passives_config.poison_master.duration_bonus_per_level) * 9.0, 0.2825, "剧毒蔓延持续")
	close(passive_value(battle.passives_config.flame_synergy, 10), 0.40, "猛火联动")
	close(passive_value(battle.passives_config.dragon_resolve, 10), 0.40, "多重鳞片")
	close(active_value(battle.general_skills_config.pk_quick_combo, 10) * 4.0, 2.30, "电光一闪总伤害")
	close(active_value(battle.general_skills_config.pk_toxic, 10), 1.0, "污泥炸弹")
	close(active_value(battle.general_skills_config.pk_paralyze, 10), 1.5, "种子炸弹")
	close(float(battle.general_skills_config.pk_ice_beam.attack_speed_slow), 0.30, "冰冻光束攻速降低")
	if battle.general_skills_config.pk_ice_beam.has("slow"): failures.append("冰冻光束仍含移动减速")
	close(active_value(battle.general_skills_config.pk_life_dew, 10), 1.70, "生命水滴")
	close(active_value(battle.general_skills_config.pk_protect, 10), 0.40, "守住")
	close(general_value(battle.general_skills_config.tk_counter_training, 10), 0.20, "避实击虚")
	close(general_value(battle.general_skills_config.pk_critical_eye, 10), 0.22, "精神回响")
	close(float(battle.general_skills_config.tk_iron_will.health) + float(battle.general_skills_config.tk_iron_will.power_per_level) * 9.0, 0.16, "铜墙铁壁生命")
	close(float(battle.general_skills_config.tk_iron_will.defense) + float(battle.general_skills_config.tk_iron_will.power_per_level) * 9.0, 0.16, "铜墙铁壁防御")
	close(float(battle.general_skills_config.pk_friend_guard.health) + float(battle.general_skills_config.pk_friend_guard.health_per_level) * 9.0, 0.18, "坚硬外壳生命")
	close(float(battle.general_skills_config.pk_friend_guard.defense) + float(battle.general_skills_config.pk_friend_guard.defense_per_level) * 9.0, 0.18, "坚硬外壳防御")
	var ui = CharacterUIScript.new(); ui.battle = battle
	var guard_text := ui.skill_numeric_description(battle.general_skills_config.pk_friend_guard, 10, "passive", false)
	if "生命 +18.0%，防御 +18.0%" not in guard_text: failures.append("坚硬外壳UI未显示独立满级数值")
	ui.free()

func _reset_combat() -> void:
	battle.clear_combatants()

func _set_exclusive_levels(actor_id: String, active: int, passive: int) -> void:
	battle.progression.ensure_growth_layout()
	battle.progression.skill_levels[actor_id]["active"] = active
	battle.progression.skill_levels[actor_id]["passive"] = passive

func _validate_skill_behaviors() -> void:
	_reset_combat(); _set_exclusive_levels("snorlax", 10, 10)
	var snorlax = battle.spawn_unit("snorlax", "heroes", Vector2(220, 220))
	var enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(500, 220)); snorlax.target = enemy
	close(snorlax.life_regen / snorlax.max_hp, 0.04, "厚脂按最终最大生命恢复")
	snorlax.hp = snorlax.max_hp * 0.25
	if snorlax.try_use_skill(): failures.append("睡觉在25%生命时错误施放")
	snorlax.hp = snorlax.max_hp * 0.24
	if not snorlax.try_use_skill(): failures.append("睡觉在24%生命时未施放")

	_reset_combat(); _set_exclusive_levels("squirtle", 10, 10)
	var squirtle = battle.spawn_unit("squirtle", "heroes", Vector2(220, 220))
	var ally = battle.spawn_unit("pikachu", "heroes", Vector2(240, 230)); ally.hp = ally.max_hp * 0.5
	enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(520, 220)); squirtle.target = enemy
	if not squirtle.try_use_skill(): failures.append("缩壳守护未释放")
	close(squirtle.shield / squirtle.max_hp, 0.40, "缩壳自身护盾", 0.002)
	close(ally.shield / ally.max_hp, 0.22, "缩壳队友护盾", 0.002)

	_reset_combat(); _set_exclusive_levels("lucario", 10, 10)
	var lucario = battle.spawn_unit("lucario", "heroes", Vector2(220, 220))
	enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(520, 220)); lucario.target = enemy
	if not lucario.try_use_skill(): failures.append("波导弹未释放")
	close(enemy.armor_break_power, 0.35, "波导弹实际破甲")

	_reset_combat(); _set_exclusive_levels("gengar", 10, 10)
	var gengar = battle.spawn_unit("gengar", "heroes", Vector2(220, 220))
	enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(520, 220)); gengar.target = enemy
	if not gengar.try_use_skill(): failures.append("毒影诅咒未释放")
	var poison_base_duration := float(gengar.skill_data.get("duration", 6.0))
	close(enemy.poison_time, poison_base_duration * 1.2825, "剧毒持续独立成长", 0.002)
	close(enemy.poison_damage, gengar.attack * gengar.active_skill_power() * 3.0, "剧毒满级伤害", 0.01)

	_reset_combat(); _set_exclusive_levels("huang_zhong", 10, 10)
	var huang = battle.spawn_unit("huang_zhong", "heroes", Vector2(220, 220))
	close(huang.physical_damage, 0.0, "鹰眼不再常驻物理增伤")

	_reset_combat()
	var caster = battle.spawn_unit("pikachu", "heroes", Vector2(220, 220))
	enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(520, 220)); caster.target = enemy
	if not caster.try_use_general_skill("pk_ice_beam"): failures.append("冰冻光束未释放")
	close(enemy.attack_speed_slow_power, 0.30, "冰冻光束实际攻速降低")
	close(enemy.slow_time, 0.0, "冰冻光束不降低移动速度")
	enemy.attack_interval = 1.0; enemy.attack_speed_slow_time = 3.2; enemy.attack_speed_slow_power = 0.3; enemy.target = caster
	enemy.basic_attack(); close(enemy.attack_timer, 1.0 / 0.7, "攻速降低使用间隔除以0.7", 0.002)

func _validate_taunts() -> void:
	var taunt_heroes: Array[String] = []
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if actor.has("enemy_type") or not actor.has("skill"): continue
		var data: Dictionary = battle.skills.get(str(actor.skill), {})
		if data.is_empty(): continue
		var probe = BattleUnitScript.new(); probe.actor_id = str(actor_id); probe.actor_data = actor; probe.skill_data = data; probe.faction = "heroes"; probe.battle = battle
		if probe.is_taunt_skill(data):
			taunt_heroes.append(str(actor_id))
			close(probe.exclusive_execution_range(float(data.get("range", 0.0))), 420.0, "英雄嘲讽范围 " + str(actor_id))
		probe.free()
	if taunt_heroes.size() < 7: failures.append("英雄嘲讽技能识别不足：%s" % str(taunt_heroes))
	_reset_combat()
	var zhang = battle.spawn_unit("zhang_fei", "heroes", Vector2(200, 220))
	zhang.general_active_ids = ["tk_challenge_shout"]
	zhang.general_active_timers = {"tk_challenge_shout": 8.0, "tk_flame_arrow": 7.0}
	zhang.skill_timer = 6.0
	zhang.warrior_committed_this_wave = true
	zhang.tank_engaged_this_wave = true
	zhang.begin_combat_wave()
	close(zhang.skill_timer, 0.0, "专属嘲讽波次刷新")
	close(float(zhang.general_active_timers.tk_challenge_shout), 0.0, "通用嘲讽波次刷新")
	close(float(zhang.general_active_timers.tk_flame_arrow), 7.0, "非嘲讽CD不刷新")
	if zhang.warrior_committed_this_wave or zhang.tank_engaged_this_wave: failures.append("波次状态未重置")
	var e300 = battle.spawn_unit("jy_bladesman", "enemies", zhang.position + Vector2(300, 0))
	var e400 = battle.spawn_unit("jy_bladesman", "enemies", zhang.position + Vector2(400, 0))
	var e450 = battle.spawn_unit("jy_bladesman", "enemies", zhang.position + Vector2(450, 0))
	for index in range(11):
		battle.spawn_unit("jy_bladesman", "enemies", zhang.position + Vector2(260 + index * 6, 40 + index * 5))
	if not zhang.try_use_skill(): failures.append("张飞420范围嘲讽未释放")
	if e300.target != zhang or e400.target != zhang or e300.taunt_timer <= 0.0 or e400.taunt_timer <= 0.0: failures.append("300/400距离未受到专属嘲讽")
	if e450.target == zhang or e450.taunt_timer > 0.0: failures.append("450距离错误受到专属嘲讽")
	var taunted := 0
	for victim in battle.enemies:
		if is_instance_valid(victim) and victim.taunt_timer > 0.0: taunted += 1
	if taunted != 12: failures.append("专属嘲讽目标上限不是12：%d" % taunted)
	e300.taunt_timer = 0.01
	battle.is_paused = false; e300._physics_process(0.02); battle.is_paused = true
	if e300.taunt_timer > 0.0: failures.append("嘲讽状态未正常到期")
	zhang.general_active_timers["tk_challenge_shout"] = 0.0
	e300.position = zhang.position + Vector2(300, 0); e400.position = zhang.position + Vector2(400, 0); e450.position = zhang.position + Vector2(450, 0)
	if not zhang.try_use_general_skill("tk_challenge_shout"): failures.append("通用挑衅未释放")
	if e300.target != zhang or e400.target != zhang or e450.target == zhang: failures.append("通用挑衅420边界错误")

func _validate_warrior_staging() -> void:
	_reset_combat()
	var tank = battle.spawn_unit("zhang_fei", "heroes", Vector2(400, 240))
	var warrior = battle.spawn_unit("guan_yu", "heroes", Vector2(180, 240))
	var enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(800, 240))
	warrior.actor_data["melee_archetype"] = "warrior"
	if not warrior.process_warrior_wait(0.016) or warrior.current_action not in ["wait_behind_tank", "hold_behind_tank"]: failures.append("坦克未接战时战士未等待跟随")
	close(warrior.position.distance_to(tank.position), 220.0, "战士初始跟随距离", 12.0)
	tank.tank_engaged_this_wave = true
	if warrior.process_warrior_wait(0.016) or not warrior.warrior_committed_this_wave: failures.append("坦克接战后战士未立即进场")
	warrior.begin_combat_wave(); tank.dead = true
	if warrior.process_warrior_wait(0.016) or not warrior.warrior_committed_this_wave: failures.append("坦克阵亡后战士卡住")
	_reset_combat()
	warrior = battle.spawn_unit("guan_yu", "heroes", Vector2(180, 240))
	warrior.actor_data["melee_archetype"] = "warrior"
	enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(800, 240))
	if warrior.process_warrior_wait(0.016) or not warrior.warrior_committed_this_wave: failures.append("无坦克时战士卡住")
