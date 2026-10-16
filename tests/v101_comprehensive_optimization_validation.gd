extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")

class ShieldBattle extends Node:
	var absorbed: Array = []
	var is_paused := false
	var suppress_combat_visuals := true
	func on_friendly_shield_absorbed(provider_id: String, source_key: String, amount: float) -> void:
		absorbed.append([provider_id, source_key, amount])

func _initialize() -> void:
	var failures: Array[String] = []
	var equipment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/v08_content.json"))
	_validate_equipment(equipment, failures)
	_validate_tank_score(equipment, failures)
	_validate_migration(equipment, failures)
	_validate_shields(failures)
	_validate_actor_baselines(failures)
	_validate_all_hero_intervals(failures)
	_validate_content(content, failures)
	if failures.is_empty():
		print("V101_COMPREHENSIVE_OPTIMIZATION_VALIDATION_PASS equipment=true tank_score=true shields=true hero_intervals=92/92 enemy_samples_unchanged=3/3 ui_content=true")
		quit(0)
		return
	for failure in failures: push_error("V101_COMPREHENSIVE_OPTIMIZATION_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_equipment(config: Dictionary, failures: Array[String]) -> void:
	if int(config.rules.inventory_capacity) != 300: failures.append("背包容量不是300")
	var quality: Dictionary = config.qualities.orange
	for level in [1, 20, 40, 44, 60, 80, 100]:
		for stat in ["health", "defense"]:
			var row: Dictionary = config.affixes[stat]
			var minimum := (float(row.min) + float(level - 1) * float(row.min_level_scale)) * float(quality.value_multiplier)
			var maximum := (float(row.max) + float(level - 1) * float(row.max_level_scale)) * float(quality.value_multiplier)
			if minimum <= 0.0 or maximum <= minimum: failures.append("%s Lv.%d成长区间无效" % [stat, level])
	var hp44 := (float(config.affixes.health.min) + 43.0 * float(config.affixes.health.min_level_scale)) * float(quality.value_multiplier)
	var hp44_max := (float(config.affixes.health.max) + 43.0 * float(config.affixes.health.max_level_scale)) * float(quality.value_multiplier)
	var def44 := (float(config.affixes.defense.min) + 43.0 * float(config.affixes.defense.min_level_scale)) * float(quality.value_multiplier)
	var def44_max := (float(config.affixes.defense.max) + 43.0 * float(config.affixes.defense.max_level_scale)) * float(quality.value_multiplier)
	if absf(hp44 - 156.0) > 0.05 or absf(hp44_max - 250.0) > 0.05: failures.append("Lv44橙色生命词条未校准到156—250")
	if absf(def44 - 71.0) > 0.05 or absf(def44_max - 114.0) > 0.05: failures.append("Lv44橙色防御词条未校准到71—114")

func _validate_tank_score(config: Dictionary, failures: Array[String]) -> void:
	var inventory = InventoryManagerScript.new(); inventory.setup(config)
	var item := {"base_stats":{"health":150.0,"defense":50.0,"attack":99999.0},"affixes":[{"stat":"damage_reduction","value":0.10},{"stat":"cooldown_reduction","value":0.20}],"world_affix":{}}
	var score := inventory.item_score(item, "tank", {"base_health":1000.0,"boss_attack":200.0})
	var expected := 150.0 / 1.5 / 1000.0 * 100.0 + 50.0 / 200.0 * 100.0 + 0.10 * 100.0 + 0.20 * 50.0
	if absf(score - expected) > 0.0001: failures.append("坦克装备评分公式不精确")
	item.base_stats.attack = 1.0
	if absf(inventory.item_score(item, "tank", {"base_health":1000.0,"boss_attack":200.0}) - expected) > 0.0001: failures.append("坦克评分错误计入攻击属性")
	inventory.free()

func _validate_migration(config: Dictionary, failures: Array[String]) -> void:
	var path := "user://v101_equipment_migration.json"
	var payload := {"version":"0.8", "affix_config_version":2, "equipment_balance_version":2, "items":[{"instance_id":"legacy","name":"旧装备","quality":"orange","quality_rank":4,"level":44,"slot":"armor","compatible_slots":["armor"],"base_stats":{"defense":100.0},"affixes":[{"stat":"health","value":130.0}]}], "equipped":{}}
	var file := FileAccess.open(path, FileAccess.WRITE); file.store_string(JSON.stringify(payload)); file.close()
	var first = InventoryManagerScript.new(); first.setup(config); first.save_path = path
	if not first.load_from_disk(): failures.append("装备平衡迁移无法读取旧存档")
	var once_base := float(first.items[0].base_stats.defense)
	var once_affix := float(first.items[0].affixes[0].value)
	first.free()
	var second = InventoryManagerScript.new(); second.setup(config); second.save_path = path
	if not second.load_from_disk() or not is_equal_approx(float(second.items[0].base_stats.defense), once_base) or not is_equal_approx(float(second.items[0].affixes[0].value), once_affix):
		failures.append("装备平衡迁移重复执行")
	second.free()
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _validate_shields(failures: Array[String]) -> void:
	var battle := ShieldBattle.new(); root.add_child(battle)
	var unit = BattleUnitScript.new(); battle.add_child(unit)
	unit.battle = battle; unit.faction = "heroes"; unit.actor_id = "target"; unit.actor_data = {"name":"目标","skill":"guard"}
	unit.add_shield(100.0, 0.5, unit, "first")
	unit.add_shield(50.0, 2.0, unit, "second")
	if not is_equal_approx(unit.shield, 150.0) or unit.shield_layers.size() != 2: failures.append("护盾没有按独立层相加")
	unit.consume_shield_layers(120.0)
	if not is_equal_approx(unit.shield, 30.0) or battle.absorbed.size() != 2: failures.append("护盾未按FIFO消费或归属统计错误")
	unit.add_shield(40.0, 0.25, unit, "short")
	unit._tick_shield_layers(0.30)
	if not is_equal_approx(unit.shield, 30.0) or unit.shield_layers.size() != 1: failures.append("护盾没有独立到期")
	battle.free()

func _validate_actor_baselines(failures: Array[String]) -> void:
	var controller = BattleControllerScript.new()
	controller.actors = {"pikachu":{"attack_interval":0.82}, "zhao_yun":{"attack_interval":1.22}, "enemy":{"attack_interval":0.50}}
	controller.apply_playable_attack_interval_baseline()
	if not is_equal_approx(float(controller.actors.pikachu.attack_interval), 0.95): failures.append("皮卡丘基础攻速未校准到0.95")
	if not is_equal_approx(float(controller.actors.zhao_yun.attack_interval), 1.05): failures.append("英雄基础攻速上限未校准到1.05")
	if not is_equal_approx(float(controller.actors.enemy.attack_interval), 0.50): failures.append("敌人攻速被错误修改")
	controller.free()

func _validate_all_hero_intervals(failures: Array[String]) -> void:
	var actors: Dictionary = {}
	for path in ["res://data/actors.json", "res://data/v08_content.json", "res://data/v09_wow_content.json", "res://data/v09_jinyong_content.json", "res://data/v10_qin_content.json", "res://data/v10_naruto_content.json", "res://data/v11_huangyi_content.json", "res://data/v12_fengyun_content.json"]:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY: actors.merge(parsed.get("actors", parsed), true)
	var hero_ids: Array = []
	# InventoryManager and ProgressionManager intentionally share this canonical
	# list. Reading it here guarantees every currently recruitable hero is audited.
	hero_ids.assign(ProgressionManagerScript.ALL_HERO_IDS)
	if hero_ids.size() != 92: failures.append("可招募英雄清单不是92名：%d" % hero_ids.size())
	for actor_id in hero_ids:
		if not actors.has(actor_id): failures.append("缺少英雄配置：" + str(actor_id)); continue
		var interval := float(actors[actor_id].get("attack_interval", -1.0))
		if interval < 0.95 or interval > 1.05: failures.append("英雄基础攻击间隔越界：%s=%.2f" % [actor_id, interval])
	# Representative enemies remain deliberately outside the hero-only band.
	if not is_equal_approx(float(actors.stage_guardian_tk.attack_interval), 1.15): failures.append("普通怪基础攻击间隔被误改")
	if not is_equal_approx(float(actors.wow_boss_hogger.attack_interval), 0.86): failures.append("Boss基础攻击间隔被误改")
	if not is_equal_approx(float(actors.fy_boss_di_shitian.attack_interval), 0.62): failures.append("后期Boss基础攻击间隔被误改")

func _validate_content(content: Dictionary, failures: Array[String]) -> void:
	var passive: Dictionary = content.passives.immovable_mountain
	if absf(float(passive.value) - 0.16) > 0.0001 or absf(float(passive.value) + 9.0 * float(passive.per_level) - 0.24) > 0.0002:
		failures.append("不动如山Lv1/Lv10数值错误")
	var ui_source := FileAccess.get_file_as_string("res://scripts/v03_ui.gd")
	if "[\"营地\", \"camp\"]" in ui_source or "[\"技能\", \"strategy\"]" in ui_source: failures.append("主菜单仍保留营地或独立技能入口")
	if "[\"图鉴\", \"codex\"]" not in ui_source or "[\"挂机设置\", \"objectives\"]" not in ui_source: failures.append("图鉴或挂机设置入口未接入")
