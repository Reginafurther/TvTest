extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")

const SUPPORTED_GENERAL_EFFECTS := [
	"damage", "stun", "low_hp_damage", "leech_damage", "self_cost_damage", "multi_hit", "area_damage", "chain",
	"armor_break", "burn", "poison", "shock", "freeze", "heal", "hot", "team_hot", "cleanse", "taunt", "shield",
	"damage_reduction", "damage_share", "evasion", "counter", "move_speed", "cooldown", "blood_boost"
]
const SUPPORTED_PASSIVE_EFFECTS := [
	"health_regen", "attack_speed", "elemental_damage", "critical", "cooldown_reduction", "second_wind", "metamorphosis",
	"healing", "damage_reduction", "low_hp_rage", "boss_slayer", "combo", "team_haste", "poison_master", "execute_damage",
	"armor_ignore", "control_haste", "burn_master", "shield_healing", "high_hp_guard", "evasion", "status_amplifier",
	"summon_damage", "stat_attack", "stat_guard", "regeneration", "low_hp_regeneration", "move_speed", "friend_guard",
	"life_steal", "multi_hit_bonus", "on_hit_status", "on_kill_haste", "shield_power", "skill_echo", "status_mastery"
]

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	_validate_212_catalog()
	_validate_all_exclusive_actives()
	_validate_all_general_actives()
	_validate_targeted_mechanics()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V09_SKILL_EFFECTS_VALIDATION_PASS exclusive_active=52 exclusive_passive=52 general_active=60 general_passive=48 total=212 casts=true targeted=true")
		quit(0)
		return
	for failure in failures: push_error("V09_SKILL_EFFECTS_VALIDATION_FAIL: " + failure)
	quit(1)

func playable_actor_ids() -> Array[String]:
	var ids: Array[String] = []
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if not actor.has("enemy_type") and actor.has("skill") and actor.has("passive_skill"): ids.append(str(actor_id))
	return ids

func _validate_212_catalog() -> void:
	var actors := playable_actor_ids()
	var active_count := 0
	var passive_count := 0
	for skill_id in battle.general_skills_config:
		var row: Dictionary = battle.general_skills_config[skill_id]
		if str(row.get("category", "")) == "active":
			active_count += 1
			if str(row.get("effect", "")) not in SUPPORTED_GENERAL_EFFECTS: failures.append("通用主动没有执行分支：%s" % skill_id)
		else:
			passive_count += 1
			if str(row.get("effect", "")) not in SUPPORTED_PASSIVE_EFFECTS: failures.append("通用被动没有执行分支：%s" % skill_id)
	for actor_id in actors:
		var actor: Dictionary = battle.actors[actor_id]
		if not battle.skills.has(str(actor.skill)): failures.append("专属主动缺失：%s" % actor_id)
		if not battle.passives_config.has(str(actor.passive_skill)): failures.append("专属被动缺失：%s" % actor_id)
		elif str(battle.passives_config[actor.passive_skill].get("effect", "")) not in SUPPORTED_PASSIVE_EFFECTS: failures.append("专属被动没有执行分支：%s" % actor_id)
	if actors.size() != 52 or active_count != 60 or passive_count != 48:
		failures.append("技能目录数量错误：%d/%d/%d/%d" % [actors.size(), actors.size(), active_count, passive_count])

func _combat_fixture(actor_id: String) -> Dictionary:
	battle.clear_combatants()
	var hero = battle.spawn_unit(actor_id, "heroes", Vector2(300, 260))
	var ally = battle.spawn_unit("liu_bei" if actor_id != "liu_bei" else "zhao_yun", "heroes", Vector2(330, 270))
	var enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(360, 260))
	hero.target = enemy
	ally.hp = ally.max_hp * 0.25
	hero.hp = hero.max_hp * 0.35
	enemy.hp = enemy.max_hp * 0.30
	return {"hero":hero, "ally":ally, "enemy":enemy}

func _validate_all_exclusive_actives() -> void:
	for actor_id in playable_actor_ids():
		var fixture := _combat_fixture(actor_id)
		var hero = fixture.hero
		if not hero.try_use_skill(): failures.append("专属主动无法在合法条件释放：%s/%s" % [actor_id, hero.actor_data.skill])

func _validate_all_general_actives() -> void:
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		if str(data.get("category", "")) != "active": continue
		var fixture := _combat_fixture("zhao_yun")
		var hero = fixture.hero
		hero.general_active_timers[skill_id] = 0.0
		if not hero.try_use_general_skill(str(skill_id)): failures.append("通用主动无法在合法条件释放：%s" % skill_id)

func _validate_targeted_mechanics() -> void:
	var fixture := _combat_fixture("zhao_yun")
	var zhao = fixture.hero; var enemy = fixture.enemy
	var old_position: Vector2 = zhao.position
	zhao.try_use_skill()
	if zhao.position == old_position: failures.append("赵云七进七出没有实际突进")

	fixture = _combat_fixture("huang_zhong")
	var huang = fixture.hero; enemy = fixture.enemy
	enemy.temporary_evasion = 1.0; enemy.temporary_evasion_time = 10.0
	var guaranteed_hp: float = enemy.hp
	huang.try_use_skill()
	if enemy.hp >= guaranteed_hp: failures.append("黄忠百步穿杨没有绕过普通闪避")

	fixture = _combat_fixture("lucario")
	var lucario = fixture.hero; enemy = fixture.enemy
	enemy.temporary_evasion = 1.0; enemy.temporary_evasion_time = 10.0
	guaranteed_hp = enemy.hp
	lucario.try_use_skill()
	if enemy.hp >= guaranteed_hp: failures.append("路卡利欧波导弹没有绕过普通闪避")

	fixture = _combat_fixture("zhang_fei")
	var zhang = fixture.hero
	zhang.try_use_skill()
	if zhang.shield <= 0.0 or zhang.temporary_reduction_time <= 0.0: failures.append("张飞主动缺少护盾或限时减伤")

	fixture = _combat_fixture("charmander")
	var charmander = fixture.hero; enemy = fixture.enemy
	enemy.apply_burn(2.0, 9.0, charmander); charmander.try_use_skill()
	if enemy.burn_time > 10.0: failures.append("小火龙燃烧延长突破10秒上限")

	fixture = _combat_fixture("lu_mingfei")
	var mingfei = fixture.hero; var ally = fixture.ally
	if not mingfei.try_use_skill() or mingfei.try_use_skill() or not mingfei.rescue_used_targets.has(str(ally.actor_id)):
		failures.append("路明非救援没有执行每目标每场一次限制")

	fixture = _combat_fixture("nine_spirits")
	var nine = fixture.hero
	nine.try_use_skill()
	var summoned: Array = battle.heroes.filter(func(unit): return unit.is_summon)
	if summoned.is_empty() or summoned[0].actor_id != "medicine_avatar" or summoned[0].actor_data.has("boss_id"):
		failures.append("九灵没有召唤独立药人单位")

	fixture = _combat_fixture("jaina_proudmoore")
	var jaina = fixture.hero; enemy = fixture.enemy
	jaina.try_use_skill()
	if enemy.frost_time <= 0.0 or enemy.burn_time > 0.0: failures.append("吉安娜暴风雪没有使用独立冰霜持续伤害")

	fixture = _combat_fixture("ren_yingying")
	var yingying = fixture.hero; enemy = fixture.enemy
	yingying.try_use_skill()
	if enemy.burn_time > 0.0 or enemy.slow_time <= 0.0: failures.append("任盈盈琴刃错误附加燃烧或没有扰乱")

	fixture = _combat_fixture("qiao_feng")
	var qiao = fixture.hero; enemy = fixture.enemy
	var hp_before: float = enemy.hp
	qiao.try_use_skill()
	if enemy.hp >= hp_before: failures.append("乔峰擒龙功没有实际伤害")

	fixture = _combat_fixture("thrall")
	var thrall = fixture.hero; ally = fixture.ally
	thrall.try_use_skill()
	if ally.haste_time <= 0.0 or ally.haste_power <= 0.0: failures.append("萨尔嗜血没有提供团队攻速增益")

	fixture = _combat_fixture("plain_question")
	var plain = fixture.hero; ally = fixture.ally
	ally.apply_poison(2.0, 5.0, enemy, 0)
	plain.try_use_skill()
	if ally.hot_time <= 0.0 or ally.poison_time > 0.0: failures.append("素问彩翼没有持续治疗或有限净化")

	fixture = _combat_fixture("zhao_yun")
	zhao = fixture.hero; enemy = fixture.enemy
	zhao.general_passive_datas = [{"id":"nh_sustained_assault", "data":{"effect":"combo", "power":2.0, "power_per_level":0.0}}]
	enemy.hp = 10000.0; enemy.max_hp = 10000.0; enemy.defense = 0.0
	zhao.attack = 50.0; zhao.crit_chance = 0.0; zhao.target = enemy
	var combo_hp: float = enemy.hp
	zhao.basic_attack()
	if combo_hp - enemy.hp > 100.0: failures.append("三击连击被动错误地在第一击触发")
	zhao.attack_timer = 0.0; zhao.basic_attack(); zhao.attack_timer = 0.0
	var before_third: float = enemy.hp; zhao.basic_attack()
	if before_third - enemy.hp <= 100.0: failures.append("同目标第三次普攻没有触发连击强化")
