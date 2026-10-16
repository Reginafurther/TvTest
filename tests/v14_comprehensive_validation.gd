extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	_validate_three_kingdoms_catalog()
	_validate_diao_chan_and_zhou_yu()
	_validate_jinyong_passives()
	_validate_party_equipment_exchange()
	_validate_world_defense_context()
	_validate_war_banner_icd()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V14_COMPREHENSIVE_VALIDATION_PASS descriptions=46 diao_damage=55% diao_cd=8.20/6.36 zhou_burn_bonus=51% equipment_slots=9 world_defense_ratio=0.90 rift_ratio=1.00 nine_yin=20%-200% beiming=4%-40% huang_compensation=116% war_banner_triggers=0s/12s")
		quit(0)
		return
	for failure in failures: push_error("V14_COMPREHENSIVE_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_three_kingdoms_catalog() -> void:
	var hero_ids := ["zhao_yun", "liu_bei", "zhang_fei", "dian_wei", "zhuge_liang", "lu_bu", "guan_yu", "huang_zhong", "diao_chan", "zhou_yu"]
	var active_descriptions := {
		"zhao_yun":"向目标突进最多68距离，造成175% → 364%攻击力的物理伤害。",
		"liu_bei":"治疗生命比例最低且血量低于88%的队友，基础治疗倍率为135% → 268.65%攻击力，并附加持续6秒的护盾。实际治疗还受到主动治疗系数及治疗加成影响。",
		"zhang_fei":"嘲讽附近最多12名敌人3秒，获得相当于自身最大生命12% → 20.64%的护盾，并减伤22%，持续3秒。",
		"dian_wei":"对单体造成190% → 412.3%攻击力的物理伤害；自身生命不高于40%时，本次伤害额外×1.45。",
		"zhuge_liang":"立即缩短全队当前专属主动技能的剩余冷却20% → 38%。",
		"lu_bu":"对周围最多12名敌人造成165% → 358.05%攻击力的范围物理伤害。",
		"guan_yu":"最多攻击5名敌人，每名敌人受到162% → 336.96%攻击力的物理伤害，降低防御18%持续5秒；目标生命不高于35%时，本次伤害额外×1.55。",
		"huang_zhong":"对单体造成215% → 427.85%攻击力的物理伤害，忽略目标42%的防御效果，并绕过闪避判定。",
		"diao_chan":"对目标固定造成55%攻击力的伤害，施加2.2秒硬直控制、降低防御16%持续5秒，并推进最多4名队友的当前技能冷却。升级只缩短技能冷却。",
		"zhou_yu":"最多攻击8名敌人，立即造成42% → 87.36%攻击力的元素伤害，并附加每秒24%攻击力、持续6秒的燃烧。"
	}
	var passive_descriptions := {
		"zhao_yun":"每累计3次普通攻击，额外追加一次55% → 100%攻击力的物理伤害，更换目标不会重置计数。",
		"liu_bei":"提高自身治疗效果18% → 40.5%，同时增强「仁德之援」的治疗量和附加护盾量。",
		"zhang_fei":"常驻降低受到的伤害15% → 28.5%，与装备减伤独立计算。",
		"dian_wei":"自身生命低于40%时，普通攻击伤害提高35% → 71%；生命低于50%时，受到有效伤害会按该比例反击攻击者。",
		"zhuge_liang":"诸葛亮存活并在战场时，全队专属主动技能的冷却缩短8% → 18.8%。",
		"lu_bu":"对Boss造成的伤害提高22% → 49%，作用于普通攻击及专属范围主动技能。",
		"guan_yu":"攻击生命不高于35%的敌人时，额外提高22% → 44.5%的伤害，包括普通攻击及专属主动技能。",
		"huang_zhong":"常驻提高16% → 34%的物理伤害，同时普通攻击和专属主动「百步穿杨」额外获得16% → 34%的防御穿透。",
		"diao_chan":"「闭月离间」命中后，立即缩短最多4名队友当前技能的剩余冷却8% → 18.8%。",
		"zhou_yu":"提高燃烧伤害，对燃烧目标额外增伤。"
	}
	for actor_id in hero_ids:
		var actor: Dictionary = battle.actors[actor_id]
		if str(battle.skills[actor.skill].description) != str(active_descriptions[actor_id]): failures.append("专属主动描述不匹配：%s" % actor_id)
		if str(battle.passives_config[actor.passive_skill].description) != str(passive_descriptions[actor_id]): failures.append("专属被动描述不匹配：%s" % actor_id)
	var general_descriptions := {
		"tk_whirlwind":"对目标附近最多6名敌人造成105% → 161.7%攻击力的范围物理伤害。",
		"tk_triple_slash":"对单体连续攻击3次，每次造成52% → 68.38%攻击力的物理伤害，总计156% → 205.14%，每段独立结算防御。",
		"tk_armor_break":"对单体造成90% → 130.5%攻击力的物理伤害，并降低目标防御28%，持续5秒。",
		"tk_flame_arrow":"远距离攻击单体，造成72% → 101.16%攻击力的物理伤害。",
		"tk_poison_dart":"对单体造成62% → 84.32%攻击力的伤害，并附加每秒18%攻击力、持续6秒的燃烧。",
		"tk_thunder_talisman":"对单体造成100% → 149.5%攻击力的伤害，并施加1.5秒硬直；Boss受到控制抗性和累计控制上限限制。",
		"tk_frost_strategy":"对单体造成75% → 102%攻击力的伤害；自身生命不高于40%时，本次伤害额外提高65%。",
		"tk_benevolent_heal":"治疗生命比例最低的受伤队友，基础治疗倍率为100% → 154%攻击力，实际治疗受到主动治疗系数及治疗加成影响。",
		"tk_recovery_banner":"使受伤队友在6秒内持续恢复生命，基础总治疗倍率为22% → 25.96%攻击力，并受到治疗加成影响。",
		"tk_purify":"清除一名队友的负面状态，并恢复相当于45% → 57.15%攻击力的基础治疗量。",
		"tk_challenge_shout":"嘲讽附近最多12名敌人3.5秒，并获得相当于自身最大生命8% → 8.864%的护盾，持续6秒。",
		"tk_iron_wall":"为最多4名队友附加护盾，每人的护盾量为施法者最大生命的16% → 18.16%，持续6秒。",
		"tk_guard_order":"为一名受伤队友分担22% → 24.376%的伤害，持续5秒。",
		"tk_shared_fate":"自身移动速度和普通攻击频率提高28% → 30.52%，持续5秒。",
		"tk_swift_step":"自身闪避率临时提高38% → 44.84%，持续4秒。",
		"tk_counter_stance":"进入持续5秒的反击状态，受到有效伤害后，对攻击者造成相当于自身攻击力65% → 85.475%的反击伤害。",
		"tk_battle_focus":"常驻提高自身攻击力9% → 19.8%。",
		"tk_iron_will":"常驻提高自身最大生命和防御10% → 20.8%。",
		"tk_swift_assault":"常驻提高自身攻击速度10% → 20.8%。",
		"tk_strategic_mind":"常驻提高自身治疗效果8% → 17%，作用于符合条件的普通攻击治疗与主动技能治疗。",
		"tk_veteran_guard":"常驻降低自身受到的伤害7% → 14.2%，与其他独立减伤层共同结算。",
		"tk_poison_edge":"常驻提高自身攻击力9% → 19.8%。",
		"tk_burning_will":"提高自身施加的燃烧伤害与持续时间22% → 40%。",
		"tk_kill_momentum":"击杀敌人后，自身攻击力与普通攻击速度提高12% → 22.8%，持续5秒。",
		"tk_counter_training":"常驻提高自身暴击率14% → 24.8%。",
		"tk_formation_aegis":"使自身及附近220距离内的队友受到的伤害降低6% → 11.4%，多个光环遵循现有减伤上限。"
	}
	var general_count := 0
	for skill_id in battle.general_skills_config:
		var row: Dictionary = battle.general_skills_config[skill_id]
		if str(row.get("world", "")) != "三国": continue
		general_count += 1
		if not general_descriptions.has(skill_id) or str(row.get("description", "")) != str(general_descriptions.get(skill_id, "")):
			failures.append("通用技能描述不匹配：%s" % skill_id)
	if general_count != 26 or general_descriptions.size() != 26: failures.append("三国通用技能数量不是26：%d" % general_count)
	var focus: Dictionary = battle.general_skills_config.tk_battle_focus
	var edge: Dictionary = battle.general_skills_config.tk_poison_edge
	if not is_equal_approx(float(edge.power), float(focus.power)) or not is_equal_approx(float(edge.power_per_level), float(focus.power_per_level)):
		failures.append("越战越勇没有与兵刃精通统一")
	if str(edge.description) != "常驻提高自身攻击力9% → 19.8%。": failures.append("越战越勇描述错误")

func _set_exclusive_levels(actor_id: String, active: int, passive: int) -> void:
	battle.progression.ensure_growth_layout()
	battle.progression.skill_levels[actor_id]["active"] = active
	battle.progression.skill_levels[actor_id]["passive"] = passive

func _set_general_passive(unit, skill_id: String, level: int) -> void:
	battle.progression.ensure_growth_layout()
	battle.progression.general_skill_levels[unit.actor_id][skill_id] = level
	unit.general_passive_datas = [{"id":skill_id, "data":battle.general_skills_config[skill_id]}]

func _combat_pair(actor_id: String, enemy_id: String = "jy_bladesman") -> Dictionary:
	battle.clear_combatants()
	battle.active_rift_context.clear()
	var hero = battle.spawn_unit(actor_id, "heroes", Vector2(300, 260))
	var enemy = battle.spawn_unit(enemy_id, "enemies", Vector2(360, 260))
	hero.target = enemy
	enemy.defense = 0.0
	enemy.max_hp = 10000.0
	enemy.hp = enemy.max_hp
	enemy.clear_shields()
	return {"hero":hero, "enemy":enemy}

func _validate_diao_chan_and_zhou_yu() -> void:
	_set_exclusive_levels("diao_chan", 10, 10)
	var fixture := _combat_pair("diao_chan")
	var diao = fixture.hero
	var enemy = fixture.enemy
	var ally = battle.spawn_unit("zhao_yun", "heroes", Vector2(320, 270))
	diao.attack = 100.0
	ally.skill_timer = 10.0
	var hp_before: float = enemy.hp
	if not diao.try_use_skill(): failures.append("貂蝉专属主动未释放")
	if not is_equal_approx(hp_before - enemy.hp, 55.0): failures.append("貂蝉满级伤害不是固定55%%：%.2f" % (hp_before - enemy.hp))
	if absf(diao.skill_timer - 6.355) > 0.001: failures.append("貂蝉满级冷却错误：%.3f" % diao.skill_timer)
	if absf(ally.skill_timer - 8.12) > 0.001: failures.append("倾城舞姿冷却推进错误：%.3f" % ally.skill_timer)
	var diao_data: Dictionary = battle.skills.closed_moon_scheme
	if not is_equal_approx(float(diao_data.power), 0.55) or not is_zero_approx(float(diao_data.power_per_level)): failures.append("貂蝉配置仍有伤害成长")
	var ui = CharacterUIScript.new()
	ui.battle = battle
	var diao_panel: String = ui.skill_numeric_description(diao_data, 1, "active", true)
	if "55.0%" not in diao_panel or "当前冷却：8.20秒" not in diao_panel or "升级至Lv.2冷却：8.00秒" not in diao_panel:
		failures.append("貂蝉技能UI没有显示固定伤害与下一级冷却：%s" % diao_panel.replace("\n", " | "))
	ui.free()

	_set_exclusive_levels("zhou_yu", 1, 10)
	fixture = _combat_pair("zhou_yu")
	var zhou = fixture.hero
	enemy = fixture.enemy
	enemy.burn_time = 2.0
	var result: Dictionary = enemy.take_damage(100.0, zhou, false, {"kind":"basic", "damage_type":"none", "allow_triggers":false})
	if not is_equal_approx(float(result.hp_damage), 151.0): failures.append("周瑜燃烧目标普攻没有只结算一次51%%：%.2f" % float(result.hp_damage))

func _passive_damage(skill_id: String, level: int, defense: float, shield_amount: float, kind: String) -> Dictionary:
	var fixture := _combat_pair("guo_jing")
	var hero = fixture.hero
	var enemy = fixture.enemy
	_set_general_passive(hero, skill_id, level)
	enemy.defense = defense
	if shield_amount > 0.0: enemy.add_shield(shield_amount, 20.0)
	return enemy.take_damage(100.0, hero, false, {"kind":kind, "damage_type":"none", "allow_triggers":false})

func _total_damage(result: Dictionary) -> float:
	return float(result.hp_damage) + float(result.shield_absorbed)

func _validate_jinyong_passives() -> void:
	var nine: Dictionary = battle.general_skills_config.jy_nine_yin
	var beiming: Dictionary = battle.general_skills_config.jy_beiming
	if str(nine.effect) != "shield_target_damage" or str(nine.function_type) != "damage": failures.append("九阴真经仍是旧攻击属性机制")
	if str(beiming.effect) != "defense_compensation" or str(beiming.function_type) != "damage": failures.append("北冥神功仍是旧吸血机制")
	if not is_equal_approx(_total_damage(_passive_damage("jy_nine_yin", 1, 0.0, 1000.0, "basic")), 120.0): failures.append("九阴真经1级护盾增伤不是20%")
	if not is_equal_approx(_total_damage(_passive_damage("jy_nine_yin", 10, 0.0, 1000.0, "skill")), 300.0): failures.append("九阴真经10级护盾增伤不是200%")
	if not is_equal_approx(_total_damage(_passive_damage("jy_nine_yin", 10, 0.0, 0.0, "basic")), 100.0): failures.append("九阴真经对无护盾目标错误生效")
	if not is_equal_approx(_total_damage(_passive_damage("jy_nine_yin", 1, 0.0, 1000.0, "effect")), 120.0): failures.append("九阴真经未逐次作用于持续伤害")
	if not is_equal_approx(_total_damage(_passive_damage("jy_beiming", 1, 100.0, 0.0, "basic")), 47.0): failures.append("北冥神功1级防御补偿错误")
	if not is_equal_approx(_total_damage(_passive_damage("jy_beiming", 10, 100.0, 0.0, "skill")), 67.0): failures.append("北冥神功10级防御补偿错误")
	if not is_equal_approx(_total_damage(_passive_damage("jy_beiming", 10, 100.0, 0.0, "effect")), 45.0): failures.append("北冥神功错误作用于持续/被动伤害")
	if not is_equal_approx(_total_damage(_passive_damage("jy_beiming", 10, 0.0, 0.0, "basic")), 100.0): failures.append("北冥神功在零防御目标上凭空增伤")
	_set_exclusive_levels("huang_zhong", 1, 10)
	var fixture := _combat_pair("huang_zhong")
	var huang = fixture.hero
	var enemy = fixture.enemy
	_set_general_passive(huang, "jy_beiming", 10)
	enemy.defense = 100.0
	var combined: Dictionary = enemy.take_damage(100.0 + 100.0 * 0.55 * (0.42 + 0.34), huang, false, {"kind":"skill", "damage_type":"none", "allow_triggers":false})
	if not is_equal_approx(_total_damage(combined), 109.0): failures.append("黄忠42%+34%+北冥40%=116%补偿错误：%.2f" % _total_damage(combined))
	huang.max_hp = 100.0
	huang.hp = 20.0
	huang.trigger_general_on_hit(enemy)
	if not is_equal_approx(huang.hp, 20.0): failures.append("北冥神功旧普攻吸血仍然存在")

func _equipment_item(instance_id: String, slot: String, locked: bool = false) -> Dictionary:
	var compatible := [slot]
	if slot in ["ring_1", "ring_2"]: compatible = ["ring_1", "ring_2"]
	return {"instance_id":instance_id, "name":instance_id, "slot":slot, "compatible_slots":compatible, "quality":"purple", "quality_rank":3, "level":1, "locked":locked, "base_stats":{}, "affixes":[]}

func _validate_party_equipment_exchange() -> void:
	var first := "zhang_fei"
	var second := "iron_guard"
	var third := "zhao_yun"
	var slots: Array = battle.equipment_config.slots.keys()
	battle.inventory.items = []
	battle.inventory.equipped = {}
	battle.inventory.ensure_equipment_layout()
	for index in range(slots.size()):
		var slot := str(slots[index])
		var first_item := _equipment_item("first_" + slot, slot, index == 0)
		var second_item := _equipment_item("second_" + slot, slot)
		battle.inventory.items.append(first_item)
		battle.inventory.items.append(second_item)
		battle.inventory.equipped[first][slot] = first_item.instance_id
		battle.inventory.equipped[second][slot] = second_item.instance_id
	battle.progression.roster = [first, second, third]
	battle.progression.party = [first, third, "", ""]
	var first_before: Dictionary = battle.inventory.equipped[first].duplicate(true)
	var second_before: Dictionary = battle.inventory.equipped[second].duplicate(true)
	if not battle.assign_party_member(0, second): failures.append("未上阵角色替换失败")
	if battle.progression.party[0] != second or battle.inventory.equipped[first] != second_before or battle.inventory.equipped[second] != first_before:
		failures.append("九栏装备没有完整双向交换")
	if not bool(battle.inventory.find_item("first_" + str(slots[0])).locked): failures.append("锁定装备状态未保留")
	var mappings_after_swap: Dictionary = battle.inventory.equipped.duplicate(true)
	if not battle.assign_party_member(0, third) or battle.inventory.equipped != mappings_after_swap: failures.append("已上阵角色换位错误触发装备交换")
	if not battle.assign_party_member(2, first) or battle.inventory.equipped != mappings_after_swap: failures.append("向空栏添加角色错误触发装备交换")
	battle.progression.party = [first, third, "", ""]
	var corrupt_id := str(battle.inventory.equipped[second][slots[0]])
	var corrupt_item: Dictionary = battle.inventory.find_item(corrupt_id)
	var original_compatible: Array = corrupt_item.compatible_slots.duplicate()
	corrupt_item.compatible_slots = ["invalid_slot"]
	var rollback_party: Array = battle.progression.party.duplicate()
	var rollback_equipment: Dictionary = battle.inventory.equipped.duplicate(true)
	if battle.assign_party_member(0, second): failures.append("不兼容装备校验未阻止交换")
	if battle.progression.party != rollback_party or battle.inventory.equipped != rollback_equipment: failures.append("装备校验失败未完整回滚")
	corrupt_item.compatible_slots = original_compatible
	var loaded = InventoryManagerScript.new()
	loaded.setup(battle.equipment_config)
	loaded.save_path = battle.inventory.save_path
	if not loaded.load_from_disk() or loaded.equipped[first] != second_before or loaded.equipped[second] != first_before: failures.append("交换后的九栏装备未正确持久化")
	loaded.free()

func _spawn_defense_sample(enemy_type: String, rift: bool) -> float:
	battle.clear_combatants()
	battle.active_rift_context = {"world":"three_kingdoms", "floor":30} if rift else {}
	var unit = battle.spawn_unit("yellow_turban", "enemies", Vector2(400, 260), {"defense":100.0, "enemy_type":enemy_type})
	return float(unit.defense)

func _validate_world_defense_context() -> void:
	for enemy_type in ["normal", "elite", "boss"]:
		var world_defense := _spawn_defense_sample(enemy_type, false)
		var rift_defense := _spawn_defense_sample(enemy_type, true)
		if absf(world_defense / rift_defense - 0.90) > 0.0001: failures.append("%s世界防御/秘境防御不是0.90：%.4f" % [enemy_type, world_defense / rift_defense])
	var rift_summon := _spawn_defense_sample("normal", true)
	if not is_equal_approx(rift_summon, _spawn_defense_sample("normal", true)): failures.append("秘境召唤怪防御被重复调整")

func _validate_war_banner_icd() -> void:
	battle.clear_combatants()
	battle.active_rift_context.clear()
	battle.is_paused = true
	var boss = battle.spawn_unit("qin_boss_jiwuye", "enemies", Vector2(420, 260))
	var ally = battle.spawn_unit("qin_palace_guard", "enemies", Vector2(450, 260))
	var normal_skill_cd := float(boss.skill_data.get("cooldown", 0.0))
	battle.on_skill(boss)
	if boss.war_banner_trigger_count != 1 or boss.shield_layers.size() != 1 or ally.shield_layers.size() != 1: failures.append("姬无夜单次施法没有恰好发放一层护盾")
	battle.on_skill(boss)
	if boss.war_banner_trigger_count != 1 or boss.shield_layers.size() != 1 or ally.shield_layers.size() != 1: failures.append("姬无夜12秒内重复发盾")
	boss._physics_process(12.0)
	if not is_equal_approx(boss.war_banner_icd_remaining, 12.0): failures.append("暂停期间war_banner内置CD异常流逝")
	battle.is_paused = false
	boss._physics_process(11.9)
	battle.on_skill(boss)
	if boss.war_banner_trigger_count != 1: failures.append("war_banner在11.9秒提前触发")
	boss._physics_process(0.1)
	var boss_layers_before: int = boss.shield_layers.size()
	var ally_layers_before: int = ally.shield_layers.size()
	battle.on_skill(boss)
	if boss.war_banner_trigger_count != 2 or boss.shield_layers.size() != boss_layers_before + 1 or ally.shield_layers.size() != ally_layers_before + 1: failures.append("war_banner在12秒后未再次触发")
	if not is_equal_approx(float(boss.skill_data.get("cooldown", 0.0)), normal_skill_cd): failures.append("姬无夜普通技能冷却被修改")
