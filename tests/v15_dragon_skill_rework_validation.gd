extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	validate_endpoints()
	validate_ranges_and_boss_scaling()
	validate_damage_layers()
	validate_dragon_states()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V15_DRAGON_SKILL_REWORK_PASS assertions=82 descriptions=32 cast_range=420 independent_layers=1.449 boss_attack=1.30")
		quit(0)
		return
	for failure in failures: push_error("V15_DRAGON_SKILL_REWORK_FAIL: " + failure)
	quit(1)

func close(actual: float, expected: float, label: String, tolerance := 0.001) -> void:
	if absf(actual - expected) > tolerance: failures.append("%s: %.6f != %.6f" % [label, actual, expected])

func active(data: Dictionary, level: int) -> float:
	return float(data.get("power", 0.0)) * (1.0 + float(data.get("power_per_level", 0.0)) * (level - 1))

func passive(data: Dictionary, level: int) -> float:
	return float(data.get("value", data.get("power", 0.0))) + float(data.get("per_level", data.get("power_per_level", 0.0))) * (level - 1)

func secondary(data: Dictionary, key: String, per_key: String, level: int) -> float:
	return float(data.get(key, 0.0)) * (1.0 + float(data.get(per_key, 0.0)) * (level - 1))

func validate_endpoints() -> void:
	close(active(battle.skills.sky_piercer, 1), 1.65, "方天画斩Lv1")
	close(active(battle.skills.sky_piercer, 10), 6.0, "方天画斩Lv10")
	close(active(battle.skills.shell_guard, 10), 0.80, "缩壳守护Lv10")
	close(passive(battle.passives_config.thick_fat, 10), 0.81, "厚脂守护Lv10生命")
	close(passive(battle.passives_config.static_charge, 10), 0.40, "静电加速Lv10")
	close(passive(battle.general_skills_config.pk_synchronize, 1), 0.15, "异常共鸣Lv1")
	close(passive(battle.general_skills_config.pk_synchronize, 10), 0.15, "异常共鸣Lv10")
	var active_expected := {
		"profile_lock":[1.05,4.20], "jun_flame":[1.42,2.4424], "yin_flow":[0.52,1.05],
		"dont_die":[2.15,3.8915], "devil_bargain":[0.32,0.392], "sickle_weasel":[1.72,3.80],
		"judgment":[1.75,3.60], "royal_gravity":[0.18,0.2124], "dream_tapir":[0.78,3.60],
		"mirror_pupil":[0.72,2.60]
	}
	for id in active_expected:
		close(active(battle.skills[id], 1), active_expected[id][0], id + " Lv1")
		close(active(battle.skills[id], 10), active_expected[id][1], id + " Lv10")
	var passive_expected := {
		"hyper_perception":[0.15,0.15], "eternal_golden_eye":[0.16,0.322], "ninja_shadow":[0.10,0.35],
		"wish_against_fate":[0.18,0.342], "right_and_power":[0.18,0.306], "hunting_instinct":[0.09,0.20],
		"unstable_bloodline":[0.18,0.315], "imperial_pressure":[0.12,0.21], "kazama_glass":[0.15,0.35],
		"precision_calculation":[0.08,0.25]
	}
	for id in passive_expected:
		close(passive(battle.passives_config[id], 1), passive_expected[id][0], id + " Lv1")
		close(passive(battle.passives_config[id], 10), passive_expected[id][1], id + " Lv10")
	var general_active_expected := {
		"dz_dragon_flame":[1.20,1.956], "dz_wind_blades":[0.44,0.6578], "dz_blood_boil":[0.22,0.2596],
		"dz_scale_guard":[0.20,0.2324], "dz_dream_erode":[0.72,1.044], "dz_alchemy_seal":[0.82,2.0]
	}
	for id in general_active_expected:
		close(active(battle.general_skills_config[id], 1), general_active_expected[id][0], id + " Lv1")
		close(active(battle.general_skills_config[id], 10), general_active_expected[id][1], id + " Lv10")
	var general_passive_expected := {
		"dz_golden_eye":[0.07,0.133], "dz_blood_resonance":[0.12,0.21], "dz_alchemy_affinity":[0.12,0.21],
		"dz_unyielding_soul":[0.10,0.40], "dz_word_echo":[0.08,0.134], "dz_bloodline_suppress":[0.14,0.20]
	}
	for id in general_passive_expected:
		close(passive(battle.general_skills_config[id], 1), general_passive_expected[id][0], id + " Lv1")
		close(passive(battle.general_skills_config[id], 10), general_passive_expected[id][1], id + " Lv10")
	close(secondary(battle.skills.jun_flame, "dot_power", "dot_power_per_level", 10), 0.52, "君焰燃烧Lv10")
	close(secondary(battle.skills.dream_tapir, "dot_power", "dot_power_per_level", 10), 0.28, "梦魇DOT Lv10")
	close(float(battle.skills.profile_lock.armor_break) + float(battle.skills.profile_lock.armor_break_per_level) * 9.0, 0.35, "侧写破甲Lv10")
	close(float(battle.skills.sickle_weasel.armor_break) + float(battle.skills.sickle_weasel.armor_break_per_level) * 9.0, 0.35, "镰鼬破甲Lv10")
	var description_ids := active_expected.keys() + passive_expected.keys() + general_active_expected.keys() + general_passive_expected.keys()
	var description_count := 0
	for id in description_ids:
		var data: Dictionary = battle.skills.get(id, battle.passives_config.get(id, battle.general_skills_config.get(id, {})))
		if str(data.get("description", "")).is_empty(): failures.append(id + " description为空")
		else: description_count += 1
	if description_count != 32: failures.append("龙族description数量错误：%d" % description_count)

func reset_combat() -> void:
	battle.clear_combatants()
	battle.active_rift_context = {}
	battle.damage_trace.clear()

func validate_ranges_and_boss_scaling() -> void:
	reset_combat()
	var caster = battle.spawn_unit("mewtwo", "heroes", Vector2(100, 200))
	close(caster.general_active_cast_range(battle.general_skills_config.pk_psychic_wave), 420.0, "精神强念施法距离")
	close(float(battle.general_skills_config.pk_psychic_wave.range), 420.0, "精神强念配置距离")
	close(float(battle.general_skills_config.pk_psychic_wave.get("radius", 125.0)), 125.0, "精神强念效果半径未扩大")
	battle.current_map_id = "guandu_road"
	var normal = battle.spawn_unit("yellow_turban", "enemies", Vector2(300, 200), {"enemy_type":"normal","max_hp":1000.0,"attack":100.0,"defense":0.0})
	var normal_attack: float = normal.attack
	var boss = battle.spawn_unit("yellow_turban", "enemies", Vector2(350, 200), {"enemy_type":"boss","boss_id":"v15_test","max_hp":1000.0,"attack":100.0,"defense":0.0})
	close(boss.attack / normal_attack, 1.30, "世界Boss攻击倍率")
	battle.active_rift_context = {"world":"三国","floor":10}
	var rift_normal = battle.spawn_unit("yellow_turban", "enemies", Vector2(400, 200), {"enemy_type":"normal","max_hp":1000.0,"attack":100.0,"defense":0.0})
	var rift_boss = battle.spawn_unit("yellow_turban", "enemies", Vector2(450, 200), {"enemy_type":"boss","boss_id":"v15_rift","max_hp":1000.0,"attack":100.0,"defense":0.0})
	close(rift_boss.attack / rift_normal.attack, 1.0, "秘境Boss不应用世界倍率")

func raw_damage_with_states(profile: bool, fragile: bool, status_bonus: float) -> float:
	reset_combat()
	var source = battle.spawn_unit("pikachu", "heroes", Vector2(100, 200))
	var victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(200, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	source.physical_damage = 0.0; source.elemental_damage = 0.0; source.final_damage = 0.0
	if status_bonus > 0.0:
		source.passive_skill_id = "v15_status_test"
		source.passive_data = {"effect":"status_amplifier","value":status_bonus,"per_level":0.0}
		source.passive_skill_level = 1
		victim.slow_time = 5.0
	if profile: victim.profile_vulnerability_time = 6.0
	if fragile: victim.fragile_time = 6.0
	var result: Dictionary = victim.take_damage(100.0, source, false, {"kind":"skill","damage_type":"physical","allow_triggers":false})
	return float(result.hp_damage) + float(result.shield_absorbed)

func validate_damage_layers() -> void:
	close(raw_damage_with_states(false, false, 0.20), 120.0, "异常增伤仅一次")
	close(raw_damage_with_states(true, true, 0.20), 145.0, "独立易伤1.449", 1.0)
	reset_combat()
	var gengar = battle.spawn_unit("gengar", "heroes", Vector2(100, 200))
	var victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(200, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	gengar.physical_damage = 0.0; gengar.elemental_damage = 0.0; gengar.final_damage = 0.0
	victim.poison_time = 5.0
	var direct: Dictionary = victim.take_damage(100.0, gengar, false, {"kind":"skill","damage_type":"elemental","allow_triggers":false})
	var dot: Dictionary = victim.take_damage(100.0, gengar, false, {"kind":"effect","damage_type":"elemental","poison":true,"allow_triggers":false})
	close(float(direct.hp_damage), 120.0, "中毒目标直接伤害20%")
	close(float(dot.hp_damage), 100.0, "中毒DOT不吃额外20%")

func validate_dragon_states() -> void:
	reset_combat()
	var nono = battle.spawn_unit("chen_motong", "heroes", Vector2(100, 200))
	var victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(180, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	nono.attack = 100.0; nono.crit_chance = 0.0; nono.target = victim
	seed(1501); nono.basic_attack()
	if victim.profile_vulnerability_time <= 0.0: failures.append("诺诺普攻命中未施加侧写易伤")
	reset_combat()
	var chu = battle.spawn_unit("chu_zihang", "heroes", Vector2(100, 200))
	victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(180, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	chu.attack = 100.0; chu.target = victim
	if not chu.try_use_skill(): failures.append("君焰未释放")
	if victim.fragile_time <= 0.0 or victim.burn_time <= 0.0: failures.append("君焰未施加易碎或燃烧")
	reset_combat()
	var chime = battle.spawn_unit("minamoto_chime", "heroes", Vector2(100, 200))
	victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(180, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	chime.attack = 100.0; chime.active_skill_level = 10; chime.target = victim
	if not chime.try_use_skill(): failures.append("梦貘未释放")
	close(victim.nightmare_damage, 28.0, "梦魇DOT满级每秒")
	if victim.nightmare_time <= 0.0: failures.append("梦魇DOT未建立独立状态")
	reset_combat()
	var zero = battle.spawn_unit("zero", "heroes", Vector2(100, 200))
	var copied = battle.spawn_unit("chu_zihang", "heroes", Vector2(120, 220))
	victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(180, 200), {"max_hp":100000.0,"defense":0.0,"enemy_type":"normal"})
	zero.attack = 100.0; zero.active_skill_level = 10; zero.passive_skill_level = 10; zero.target = victim
	copied.active_skill_level = 10; copied.hp = copied.max_hp * 0.5
	if not zero.try_use_skill(): failures.append("镜瞳未释放")
	if copied.shield <= 0.0: failures.append("镜瞳未给最低生命队友提供护盾")
	close(copied.shield / zero.max_hp, 0.25, "镜瞳满级护盾按零最大生命", 0.002)
