extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_validate_damage_formula()
	var battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	_validate_atomic_loadout(battle)
	var ui = CharacterUIScript.new()
	root.add_child(ui)
	ui.setup(battle)
	ui.open("stats")
	await process_frame
	if ui.damage_score_label == null or ui.damage_score_label.text.is_empty():
		failures.append("人物属性页未显示伤害能力")
	battle.clear_combatants()
	ui.queue_free()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V147_DAMAGE_SKILL_COPY_PASS damage_formula=physical_elemental_healer cdr30=1.10 slots=3+4 atomic=true persistence=true")
		quit(0)
		return
	for failure in failures: push_error("V147_DAMAGE_SKILL_COPY_FAIL: " + failure)
	quit(1)

func _validate_damage_formula() -> void:
	var base := {"attack":100.0,"crit_chance":0.25,"crit_damage":2.0,"physical_damage":0.20,"elemental_damage":0.90,"final_damage":0.10,"attack_speed":0.166,"cooldown_reduction":0.30}
	var expected := 100.0 * 1.25 * 1.20 * 1.10 * 1.166 * 1.10
	var physical := CharacterUIScript.calculate_damage_capability({"basic_damage_type":"physical"}, base)
	if not is_equal_approx(physical, expected): failures.append("物理伤害能力公式错误：%.4f != %.4f" % [physical, expected])
	var elemental_stats: Dictionary = base.duplicate(true)
	elemental_stats.physical_damage = 2.0
	elemental_stats.elemental_damage = 0.30
	var elemental := CharacterUIScript.calculate_damage_capability({"basic_damage_type":"elemental"}, elemental_stats)
	var elemental_expected := 100.0 * 1.25 * 1.30 * 1.10 * 1.166 * 1.10
	if not is_equal_approx(elemental, elemental_expected): failures.append("元素角色错误计入物理增伤")
	if CharacterUIScript.calculate_damage_capability({"basic_action":"heal","basic_damage_type":"none"}, base) >= 0.0:
		failures.append("治疗普攻未显示为无伤害能力")
	if CharacterUIScript.format_damage_capability(12345.67) != "12,345.7": failures.append("伤害能力千位格式错误")

func _validate_atomic_loadout(battle) -> void:
	var p = battle.progression
	for actor_id in ["liu_bei", "zhao_yun", "lucario"]:
		if actor_id not in p.roster: p.roster.append(actor_id)
	p.ensure_growth_layout()
	var actives: Array[String] = []
	var passives: Array[String] = []
	for skill_id in battle.general_skills_config:
		var category := str(battle.general_skills_config[skill_id].get("category", ""))
		if category == "active" and actives.size() < 3: actives.append(str(skill_id))
		if category == "passive" and passives.size() < 4: passives.append(str(skill_id))
	if actives.size() != 3 or passives.size() != 4:
		failures.append("通用技能配置不足以执行7槽测试")
		return
	var payload := {"source_actor_id":"liu_bei","source_name":"刘备","active":[],"passive":[]}
	var levels := [10, 8, 6, 10, 7, 9, 5]
	var cursor := 0
	for category in ["active", "passive"]:
		var ids: Array[String] = actives if category == "active" else passives
		for slot_index in range(ids.size()):
			payload[category].append({"skill_id":ids[slot_index],"category":category,"slot_index":slot_index,"level":levels[cursor]})
			cursor += 1
	var gold_before: int = p.gold
	var books_before: Dictionary = p.skill_books.duplicate(true)
	var source_learned_before: Array = p.learned_general_skills.liu_bei.duplicate()
	var source_levels_before: Dictionary = p.general_skill_levels.liu_bei.duplicate(true)
	var source_equipped_before: Dictionary = p.equipped_general_skills.liu_bei.duplicate(true)
	p.general_skill_levels.zhao_yun[actives[0]] = 10
	var result: Dictionary = p.apply_general_skill_loadout("zhao_yun", payload, battle.general_skills_config)
	if not bool(result.get("ok", false)): failures.append("合法整套技能粘贴失败：%s" % result.get("error", "")); return
	if p.equipped_general_skills.zhao_yun.active != actives or p.equipped_general_skills.zhao_yun.passive != passives:
		failures.append("粘贴后技能槽顺序不一致")
	if p.general_skill_level("zhao_yun", actives[0]) != 10: failures.append("目标较高技能等级被降低")
	if p.general_skill_level("zhao_yun", actives[1]) != 8: failures.append("目标较低技能等级未同步")
	if p.gold != gold_before or p.skill_books != books_before: failures.append("免费粘贴错误消耗金币或技能书")
	if p.learned_general_skills.liu_bei != source_learned_before or p.general_skill_levels.liu_bei != source_levels_before or p.equipped_general_skills.liu_bei != source_equipped_before:
		failures.append("粘贴修改了来源角色")
	p.party = ["zhao_yun", "", "", ""]
	battle.clear_combatants()
	battle.spawn_party()
	var live = battle.get_hero("zhao_yun")
	if live == null:
		failures.append("无法创建上阵角色验证热同步")
	else:
		live.general_active_ids.clear()
		live.general_passive_ids.clear()
		battle.sync_actor_general_skill_loadout("zhao_yun")
		if live.general_active_ids != actives or live.general_passive_ids != passives:
			failures.append("上阵角色没有即时同步粘贴技能")
	var empty_payload: Dictionary = payload.duplicate(true)
	empty_payload.active = payload.active.duplicate(true)
	empty_payload.passive = payload.passive.duplicate(true)
	empty_payload.active[2] = {"skill_id":"","category":"active","slot_index":2,"level":0}
	empty_payload.passive[3] = {"skill_id":"","category":"passive","slot_index":3,"level":0}
	var empty_result: Dictionary = p.apply_general_skill_loadout("lucario", empty_payload, battle.general_skills_config)
	if not bool(empty_result.get("ok", false)) or str(p.equipped_general_skills.lucario.active[2]) != "" or str(p.equipped_general_skills.lucario.passive[3]) != "":
		failures.append("跨世界粘贴未正确覆盖空槽")
	var before_invalid: Dictionary = p.equipped_general_skills.zhao_yun.duplicate(true)
	var invalid: Dictionary = payload.duplicate(true)
	invalid.active = payload.active.duplicate(true)
	invalid.active[1] = {"skill_id":"missing_skill","category":"active","slot_index":1,"level":10}
	var invalid_result: Dictionary = p.apply_general_skill_loadout("zhao_yun", invalid, battle.general_skills_config)
	if bool(invalid_result.get("ok", false)) or p.equipped_general_skills.zhao_yun != before_invalid:
		failures.append("无效技能ID没有保持原子回滚")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(p.save_path))
	if typeof(saved) != TYPE_DICTIONARY or saved.get("equipped_general_skills", {}).get("zhao_yun", {}) != p.equipped_general_skills.zhao_yun:
		failures.append("粘贴配置没有正确持久化")
