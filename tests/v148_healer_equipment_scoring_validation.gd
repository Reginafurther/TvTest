extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const InventoryUIScript = preload("res://scripts/inventory_ui.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	var inventory = InventoryManagerScript.new()
	inventory.setup(battle.equipment_config, battle.actors)
	battle.inventory = inventory
	var profile: Dictionary = battle.equipment_scoring_profile("liu_bei")
	if str(profile.combat_role) != "healer": failures.append("刘备没有解析为治疗职业评分")
	_validate_weights(inventory, profile)
	_validate_manual_views_and_optimization(battle, inventory, profile)
	battle.clear_combatants()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V148_HEALER_EQUIPMENT_SCORING_PASS zero=health/defense/reduction/final/crit/crit_damage/physical/elemental kept=attack4.5/healing520/cdr300/speed220 manual=true rings=true final_plan=true")
		quit(0)
		return
	for failure in failures: push_error("V148_HEALER_EQUIPMENT_SCORING_FAIL: " + failure)
	quit(1)

func _item(id: String, stats: Dictionary) -> Dictionary:
	return {
		"instance_id":id, "template_id":"test_ring", "name":id,
		"slot":"ring_1", "compatible_slots":["ring_1", "ring_2"],
		"quality":"purple", "quality_rank":3, "level":1,
		"base_stats":stats, "affixes":[], "world_affix":{}, "locked":false
	}

func _score(inventory, item: Dictionary, profile: Dictionary) -> float:
	return inventory.item_score(item, str(profile.combat_role), profile.scoring_context)

func _close(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) > 0.0001:
		failures.append("%s：%.4f != %.4f" % [label, actual, expected])

func _validate_weights(inventory, profile: Dictionary) -> void:
	for stat in ["health", "defense", "damage_reduction", "final_damage", "crit_chance", "crit_damage", "physical_damage", "elemental_damage"]:
		_close(_score(inventory, _item("zero_" + stat, {stat:999.0}), profile), 0.0, "治疗职业%s应为0分" % stat)
	_close(_score(inventory, _item("attack", {"attack":10.0}), profile), 45.0, "攻击权重")
	_close(_score(inventory, _item("healing", {"healing_effect":0.10}), profile), 52.0, "治疗效果权重")
	_close(_score(inventory, _item("cdr", {"cooldown_reduction":0.10}), profile), 30.0, "冷却缩减权重")
	_close(_score(inventory, _item("speed", {"attack_speed":0.10}), profile), 22.0, "攻击速度权重")
	if inventory.item_score(_item("output_health", {"health":100.0}), "ranged_dps", {"basic_damage_type":"physical"}) <= 0.0:
		failures.append("治疗权重调整误伤其他职业")

func _validate_manual_views_and_optimization(battle, inventory, profile: Dictionary) -> void:
	var survival := _item("survival", {"health":9999.0,"defense":999.0,"damage_reduction":0.45,"final_damage":0.5,"crit_chance":0.75,"crit_damage":2.0})
	var throughput_a := _item("throughput_a", {"attack":10.0,"healing_effect":0.10,"cooldown_reduction":0.10,"attack_speed":0.10})
	var throughput_b := _item("throughput_b", {"attack":5.0,"healing_effect":0.05})
	for item in [survival, throughput_a, throughput_b]: inventory.add_item(item, false)
	var expected_a := 45.0 + 52.0 + 30.0 + 22.0
	battle.progression.roster = ["liu_bei"]
	battle.progression.party = ["liu_bei", "", "", ""]
	battle.progression.ensure_growth_layout()
	var inventory_ui = InventoryUIScript.new()
	root.add_child(inventory_ui)
	inventory_ui.setup(battle)
	inventory_ui.show_comparison(throughput_a)
	if not inventory_ui.comparison.text.contains("职业综合评分变化") or not inventory_ui.comparison.text.contains("+149.0"):
		failures.append("独立背包手动对比未显示治疗职业评分：" + inventory_ui.comparison.text)
	var choices: Array = inventory.optimize_candidates("liu_bei", 0, 9, str(profile.combat_role), profile.scoring_context)
	if choices.size() != 2:
		failures.append("治疗职业双戒指优化没有选择两个有效吞吐装备")
	for choice in choices:
		if str(choice.instance_id) == "survival": failures.append("治疗职业优化选择了纯生存零分装备")
	if not choices.is_empty():
		_close(float(choices[0].pair_gain), expected_a + 48.5, "双戒指组合评分")
		var applied: int = inventory.apply_optimization("liu_bei", choices)
		if applied != 2: failures.append("治疗职业双戒指最终方案未完整应用")
		var final_score := 0.0
		for slot in ["ring_1", "ring_2"]:
			var equipped_item = inventory.get_equipped_item("liu_bei", slot)
			if equipped_item != null: final_score += _score(inventory, equipped_item, profile)
		_close(final_score, expected_a + 48.5, "最终装备映射评分")
	inventory_ui.queue_free()
	inventory.free()
