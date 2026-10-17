extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")

const NARUTO_IDS := [
	"naruto_uzumaki", "naruto_sasuke", "naruto_sakura", "naruto_kakashi",
	"naruto_itachi", "naruto_shikamaru", "naruto_hinata", "naruto_gaara",
	"naruto_jiraiya", "naruto_tsunade"
]

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.suppress_combat_visuals = true
	_validate_boss_aoe_protection()
	_validate_counter_gateway()
	_validate_naruto_art()
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V143_DAMAGE_PROTECTION_NARUTO_ART_PASS boss_aoe_cap=65% counter_icd=2.0 counter_ranged_cap=65% portraits=10 units=10 alpha=true")
		quit(0)
		return
	for failure in failures:
		push_error("V143_DAMAGE_PROTECTION_NARUTO_ART_FAIL: " + failure)
	quit(1)

func close(actual: float, expected: float, label: String, tolerance := 0.01) -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s: %.3f != %.3f" % [label, actual, expected])

func normalize_unit(unit, maximum_health := 1000.0) -> void:
	unit.max_hp = maximum_health
	unit.hp = maximum_health
	unit.base_max_hp = maximum_health
	unit.defense = 0.0
	unit.damage_reduction = 0.0
	unit.temporary_reduction = 0.0
	unit.temporary_reduction_time = 0.0
	unit.vulnerability_power = 0.0
	unit.vulnerability_time = 0.0
	unit.passive_skill_id = ""
	unit.passive_data = {}
	unit.general_passive_datas = []
	unit.shield_layers.clear()
	unit._refresh_shield_totals()
	unit.dead = false
	unit.physical_damage = 0.0
	unit.elemental_damage = 0.0
	unit.final_damage = 0.0
	unit.counter_icd_remaining = 0.0

func _validate_boss_aoe_protection() -> void:
	var boss = battle.spawn_unit("wow_boss_hogger", "enemies", Vector2(700, 250))
	var melee = battle.spawn_unit("zhao_yun", "heroes", Vector2(300, 250))
	normalize_unit(boss, 100000.0)
	normalize_unit(melee)
	boss.position = Vector2(500, 250)
	melee.position = Vector2(520, 250)
	boss.attack = 5000.0
	boss.target = melee
	if not boss.try_use_skill():
		failures.append("Boss实际AOE技能未能施放")
	else:
		close(melee.max_hp - melee.hp, 650.0, "Boss实际AOE施法链路上限")
	normalize_unit(melee)
	var physical: Dictionary = melee.take_damage(5000.0, boss, false, {"kind":"skill", "damage_type":"physical", "is_boss_aoe":true, "allow_triggers":false})
	close(float(physical.hp_damage), 650.0, "近战物理Boss AOE上限")
	normalize_unit(melee)
	var elemental: Dictionary = melee.take_damage(5000.0, boss, false, {"kind":"skill", "damage_type":"elemental", "is_boss_aoe":true, "allow_triggers":false})
	close(float(elemental.hp_damage), 650.0, "近战元素Boss AOE上限")
	normalize_unit(melee)
	melee.add_shield(300.0, 5.0, melee, "test_shield")
	var shielded: Dictionary = melee.take_damage(5000.0, boss, false, {"kind":"skill", "damage_type":"physical", "is_boss_aoe":true, "allow_triggers":false})
	close(float(shielded.shield_absorbed), 300.0, "AOE上限后的护盾吸收")
	close(float(shielded.hp_damage), 350.0, "AOE上限后的生命伤害")
	normalize_unit(melee)
	for hit in range(2):
		var multi: Dictionary = melee.take_damage(5000.0, boss, false, {"kind":"skill", "damage_type":"physical", "is_boss_aoe":true, "multi_hit":true, "allow_triggers":false})
		close(float(multi.hp_damage), 650.0, "Boss多段AOE独立上限%d" % (hit + 1))
		melee.hp = melee.max_hp
	normalize_unit(melee)
	var single_target: Dictionary = melee.take_damage(900.0, boss, false, {"kind":"skill", "damage_type":"physical", "allow_triggers":false})
	if float(single_target.hp_damage) <= 650.0: failures.append("Boss单体技能被错误限制")
	var tank = battle.spawn_unit("zhang_fei", "heroes", Vector2(320, 280))
	normalize_unit(tank)
	var tank_hit: Dictionary = tank.take_damage(900.0, boss, false, {"kind":"skill", "damage_type":"physical", "is_boss_aoe":true, "allow_triggers":false})
	if float(tank_hit.hp_damage) <= 650.0: failures.append("坦克被错误套用Boss AOE上限")
	var ranged = battle.spawn_unit("zhou_yu", "heroes", Vector2(280, 300))
	normalize_unit(ranged)
	var ranged_hit: Dictionary = ranged.take_damage(900.0, boss, false, {"kind":"skill", "damage_type":"elemental", "is_boss_aoe":true, "allow_triggers":false})
	if float(ranged_hit.hp_damage) <= 650.0: failures.append("远程职业被错误套用近战AOE上限")
	var mob = battle.spawn_unit("yellow_turban", "enemies", Vector2(680, 300))
	normalize_unit(mob, 100000.0)
	normalize_unit(melee)
	var mob_aoe: Dictionary = melee.take_damage(900.0, mob, false, {"kind":"skill", "damage_type":"physical", "is_boss_aoe":true, "allow_triggers":false})
	if float(mob_aoe.hp_damage) <= 650.0: failures.append("普通怪AOE被错误限制")

func _validate_counter_gateway() -> void:
	var counter_boss = battle.spawn_unit("wow_boss_hogger", "enemies", Vector2(720, 330), {"boss_mechanic":"counter_guard"})
	var remote = battle.spawn_unit("zhou_yu", "heroes", Vector2(280, 330))
	normalize_unit(counter_boss, 100000.0)
	normalize_unit(remote)
	counter_boss.take_damage(10000.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(remote.max_hp - remote.hp, 650.0, "远程职业反击伤害上限")
	close(counter_boss.counter_icd_remaining, 2.0, "反击成功后内置CD")
	remote.hp = remote.max_hp
	counter_boss.take_damage(10000.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(remote.hp, remote.max_hp, "2秒内重复反击")
	battle.is_paused = true
	counter_boss._physics_process(1.0)
	close(counter_boss.counter_icd_remaining, 2.0, "暂停期间反击CD错误流逝")
	battle.is_paused = false
	counter_boss.attack_timer = 999.0
	counter_boss.skill_timer = 999.0
	counter_boss.move_speed = 0.0
	counter_boss._physics_process(1.0)
	close(counter_boss.counter_icd_remaining, 1.0, "反击CD一秒流逝")
	counter_boss._physics_process(1.0)
	close(counter_boss.counter_icd_remaining, 0.0, "反击CD两秒结束")
	battle.is_paused = true
	remote.hp = remote.max_hp
	counter_boss.take_damage(10000.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(remote.max_hp - remote.hp, 650.0, "CD结束后反击恢复")
	var second_counter = battle.spawn_unit("hy_boss_li_chimei", "enemies", Vector2(740, 350), {"boss_mechanic":"counter_guard"})
	normalize_unit(second_counter, 100000.0)
	remote.hp = remote.max_hp
	second_counter.take_damage(10000.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(remote.max_hp - remote.hp, 650.0, "不同反击单位CD独立")
	var multi_source = battle.spawn_unit("wow_boss_hogger", "enemies", Vector2(735, 360), {"boss_mechanic":"counter_guard"})
	normalize_unit(multi_source, 100000.0)
	multi_source.rift_affixes = ["counter"]
	multi_source.temporary_counter = 1.0
	multi_source.temporary_counter_time = 5.0
	remote.hp = remote.max_hp
	multi_source.take_damage(100.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(remote.max_hp - remote.hp, 18.0, "同次受击多个反击来源只触发一次")
	# Each remaining counter source is routed through the same gateway.
	for source_kind in ["rift", "temporary", "passive"]:
		var counter_unit = battle.spawn_unit("yellow_turban", "enemies", Vector2(700, 370))
		normalize_unit(counter_unit, 100000.0)
		match source_kind:
			"rift": counter_unit.rift_affixes = ["counter"]
			"temporary": counter_unit.temporary_counter = 1.0; counter_unit.temporary_counter_time = 5.0; counter_unit.temporary_counter_skill_id = "test_counter_stance"
			"passive": counter_unit.general_passive_datas = [{"id":"test_counter", "data":{"effect":"counter", "power":1.0}}]
		remote.hp = remote.max_hp
		counter_unit.take_damage(10000.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
		if counter_unit.counter_icd_remaining <= 0.0: failures.append("%s反击未进入统一CD" % source_kind)
		if remote.hp >= remote.max_hp: failures.append("%s反击未造成伤害" % source_kind)
	var missed_counter = battle.spawn_unit("yellow_turban", "enemies", Vector2(700, 390))
	normalize_unit(missed_counter, 100000.0)
	missed_counter.general_passive_datas = [{"id":"test_counter_miss", "data":{"effect":"counter", "power":0.000001}}]
	seed(143)
	missed_counter.take_damage(100.0, remote, false, {"kind":"basic", "damage_type":"elemental", "allow_triggers":true})
	close(missed_counter.counter_icd_remaining, 0.0, "反击概率未命中不应启动CD")
	var low_hp = battle.spawn_unit("dian_wei", "heroes", Vector2(350, 350))
	var attacker = battle.spawn_unit("yellow_turban", "enemies", Vector2(650, 350))
	normalize_unit(low_hp)
	normalize_unit(attacker, 100000.0)
	low_hp.passive_skill_id = "low_hp_rage"
	low_hp.passive_data = battle.passives_config.low_hp_rage
	low_hp.hp = 400.0
	low_hp.take_damage(20.0, attacker, false, {"kind":"basic", "damage_type":"physical", "allow_triggers":true})
	if low_hp.counter_icd_remaining <= 0.0: failures.append("低生命反击未进入统一CD")
	# Counter damage explicitly disables trigger recursion.
	var hp_before: float = low_hp.hp
	low_hp.take_damage(20.0, attacker, false, {"kind":"counter", "is_counter_damage":true, "allow_triggers":false})
	if low_hp.counter_icd_remaining > 2.0 or low_hp.hp >= hp_before: failures.append("反击递归保护异常")

func _validate_naruto_art() -> void:
	ArtCatalogScript.reload()
	for actor_id in NARUTO_IDS:
		var portrait_path := "res://assets/portraits/naruto/%s_portrait_v1.png" % actor_id
		var unit_path := "res://assets/units/naruto/%s_battle_v1.png" % actor_id
		if ArtCatalogScript.configured_path("portraits", actor_id) != portrait_path:
			failures.append(actor_id + "角色立绘映射错误")
		if ArtCatalogScript.configured_path("units", actor_id) != unit_path:
			failures.append(actor_id + "战斗立绘映射错误")
		var portrait: Texture2D = ArtCatalogScript.portrait(actor_id)
		var unit_texture: Texture2D = ArtCatalogScript.texture("units", actor_id)
		if portrait == null or portrait.get_width() != 640 or portrait.get_height() != 960:
			failures.append(actor_id + "角色立绘未加载为640x960")
		if unit_texture == null or unit_texture.get_width() != 512 or unit_texture.get_height() != 512:
			failures.append(actor_id + "战斗立绘未加载为512x512")
		var portrait_image := portrait.get_image() if portrait != null else null
		var unit_image := unit_texture.get_image() if unit_texture != null else null
		if portrait_image == null or portrait_image.detect_alpha() == Image.ALPHA_NONE:
			failures.append(actor_id + "角色立绘缺少透明通道")
		if unit_image == null or unit_image.detect_alpha() == Image.ALPHA_NONE:
			failures.append(actor_id + "战斗立绘缺少透明通道")
		var layout := ArtCatalogScript.layout("units", actor_id)
		if layout.is_empty() or layout.get("anchor", []) != [0.5, 0.98]:
			failures.append(actor_id + "战斗脚底锚点缺失")
