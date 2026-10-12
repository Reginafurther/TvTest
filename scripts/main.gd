extends Node

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const InventoryUIScript = preload("res://scripts/inventory_ui.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")

var battle: Node2D
var stats_label: Label
var state_label: Label
var log_label: RichTextLabel
var cards: HBoxContainer
var help_label: Label
var inventory_ui
var backpack_button: Button

func _ready() -> void:
	build_background()
	battle = BattleControllerScript.new()
	battle.position = Vector2(20, 76)
	add_child(battle)
	build_ui()
	battle.stats_changed.connect(update_stats)
	battle.party_changed.connect(update_party)
	battle.log_message.connect(add_log)
	battle.battle_state_changed.connect(update_state)
	inventory_ui = InventoryUIScript.new()
	add_child(inventory_ui)
	inventory_ui.setup(battle)
	update_party(battle.heroes)
	add_log("四人小队已进入青草渡口，自动战斗开始")
	if "--persistence-write" in OS.get_cmdline_user_args():
		finish_persistence_write()
	elif "--persistence-read" in OS.get_cmdline_user_args():
		finish_persistence_read()
	elif "--equipment-test" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
		get_tree().create_timer(20.0).timeout.connect(finish_equipment_test)
	elif "--smoke-test" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
		get_tree().create_timer(20.0).timeout.connect(finish_smoke_test)

func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_R) and battle.game_over:
		battle.restart()

func build_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#16232A")
	backdrop.size = Vector2(1100, 700)
	add_child(backdrop)

func build_ui() -> void:
	var title := Label.new()
	title.text = "万界冒险团  ·  青草渡口"
	title.position = Vector2(22, 14)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#FFF2B5"))
	add_child(title)

	state_label = Label.new()
	state_label.text = "● 自动战斗中"
	state_label.position = Vector2(430, 22)
	state_label.add_theme_color_override("font_color", Color("#82EEA6"))
	add_child(state_label)

	stats_label = Label.new()
	stats_label.text = "击败 0  ·  第 1 波  ·  00:00"
	stats_label.position = Vector2(777, 22)
	stats_label.size = Vector2(300, 30)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_font_size_override("font_size", 17)
	add_child(stats_label)

	backpack_button = Button.new()
	backpack_button.text = "背包 / 装备  B"
	backpack_button.position = Vector2(610, 15)
	backpack_button.size = Vector2(150, 38)
	backpack_button.pressed.connect(_on_backpack_pressed)
	add_child(backpack_button)

	var footer := ColorRect.new()
	footer.position = Vector2(0, 596)
	footer.size = Vector2(1100, 104)
	footer.color = Color("#101B22")
	add_child(footer)

	cards = HBoxContainer.new()
	cards.position = Vector2(20, 609)
	cards.size = Vector2(760, 75)
	cards.add_theme_constant_override("separation", 8)
	add_child(cards)

	log_label = RichTextLabel.new()
	log_label.position = Vector2(792, 607)
	log_label.size = Vector2(290, 67)
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(log_label)

	help_label = Label.new()
	help_label.text = "左键地图：设置集结点    空格：暂停/继续    B：背包与装备"
	help_label.position = Vector2(20, 560)
	help_label.add_theme_color_override("font_color", Color("#E8F2DF"))
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	help_label.add_theme_constant_override("outline_size", 4)
	add_child(help_label)

func update_stats(kills: int, elapsed: float, wave: int) -> void:
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60
	stats_label.text = "击败 %d  ·  第 %d 波  ·  %02d:%02d" % [kills, wave, minutes, seconds]

func update_state(message: String) -> void:
	state_label.text = "● " + message
	state_label.add_theme_color_override("font_color", Color("#F2C66D") if battle.is_paused or battle.game_over else Color("#82EEA6"))

func update_party(party: Array) -> void:
	for child in cards.get_children():
		child.queue_free()
	for unit in party:
		if not is_instance_valid(unit):
			continue
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(180, 68)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#21333C")
		style.border_color = Color(unit.actor_data.get("color", "FFFFFF"))
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = "%s  ·  %s\nHP %d/%d  攻 %.0f  防 %.0f\n%s  %.1fs" % [unit._name(), unit.actor_data.get("role", ""), unit.hp, unit.max_hp, unit.attack, unit.defense, unit._skill_name(), unit.skill_timer]
		label.add_theme_font_size_override("font_size", 13)
		panel.add_child(label)
		cards.add_child(panel)

func add_log(message: String) -> void:
	if log_label.get_parsed_text().split("\n").size() > 18:
		log_label.clear()
	log_label.append_text("[color=#9CB5C2]›[/color] %s\n" % message)
	log_label.scroll_to_line(999)

func _on_backpack_pressed() -> void:
	inventory_ui.toggle()

func finish_smoke_test() -> void:
	var passed: bool = battle.elapsed >= 18.0 and battle.heroes.size() > 0 and battle.kills > 0
	if passed:
		print("SMOKE_TEST_PASS elapsed=%.1f kills=%d heroes=%d wave=%d" % [battle.elapsed, battle.kills, battle.heroes.size(), battle.wave - 1])
	else:
		push_error("SMOKE_TEST_FAIL elapsed=%.1f kills=%d heroes=%d" % [battle.elapsed, battle.kills, battle.heroes.size()])
	Engine.time_scale = 1.0
	get_tree().quit(0 if passed else 1)

func finish_equipment_test() -> void:
	var failures: Array[String] = []
	var inventory = battle.inventory
	if battle.kills <= 0 or inventory.items.is_empty():
		failures.append("战斗掉落未进入背包")
	if not inventory.all_ids_unique():
		failures.append("装备实例ID重复")
	for actor_id in inventory.HERO_IDS:
		if not inventory.equipped.has(actor_id) or inventory.equipped[actor_id].size() != 9:
			failures.append("%s 的9个装备栏不完整" % actor_id)
	var zhao = battle.get_hero("zhao_yun")
	var snorlax = battle.get_hero("snorlax")
	if zhao == null or snorlax == null:
		failures.append("测试角色在战斗中死亡")
	else:
		var zhao_base: Dictionary = zhao.combat_snapshot()
		var test_weapon: Dictionary = battle.equipment_generator.generate(8, "自动测试", "orange", "main_hand")
		test_weapon.affixes = [
			{"stat": "health", "value": 60.0},
			{"stat": "defense", "value": 12.0},
			{"stat": "crit_chance", "value": 0.2},
			{"stat": "crit_damage", "value": 0.4},
			{"stat": "attack_speed", "value": 0.3},
			{"stat": "cooldown_reduction", "value": 0.25}
		]
		inventory.add_item(test_weapon, false)
		var count_before: int = inventory.items.size()
		inventory.equip_item("zhao_yun", test_weapon.instance_id, "main_hand")
		var zhao_geared: Dictionary = zhao.combat_snapshot()
		if not (zhao_geared.attack > zhao_base.attack and zhao_geared.health > zhao_base.health and zhao_geared.defense > zhao_base.defense):
			failures.append("基础战斗属性未随装备提升")
		if not (zhao_geared.crit_chance > zhao_base.crit_chance and zhao_geared.attack_interval < zhao_base.attack_interval and zhao_geared.cooldown_reduction > zhao_base.cooldown_reduction):
			failures.append("暴击/攻速/冷却属性未接入战斗")
		var test_armor: Dictionary = battle.equipment_generator.generate(8, "自动测试", "purple", "armor")
		test_armor.base_stats = {"defense": 30.0, "health": 80.0}
		inventory.add_item(test_armor, false)
		var damage_before: int = snorlax.preview_damage(100.0)
		inventory.equip_item("snorlax", test_armor.instance_id, "armor")
		var damage_after: int = snorlax.preview_damage(100.0)
		if damage_after >= damage_before:
			failures.append("防御未降低实际承伤")
		inventory.unequip_slot("zhao_yun", "main_hand")
		var zhao_restored: Dictionary = zhao.combat_snapshot()
		if absf(zhao_restored.attack - zhao_base.attack) > 0.001 or absf(zhao_restored.health - zhao_base.health) > 0.001:
			failures.append("卸下后属性未恢复")
		if inventory.items.size() != count_before + 1:
			failures.append("更换/卸下导致物品丢失或复制")
		inventory.equip_item("zhao_yun", test_weapon.instance_id, "main_hand")
		inventory.save_to_disk()
		var reload_manager = InventoryManagerScript.new()
		reload_manager.setup(battle.equipment_config)
		if not reload_manager.load_from_disk():
			failures.append("存档无法重新载入")
		elif reload_manager.items.size() != inventory.items.size() or reload_manager.equipped["zhao_yun"]["main_hand"] != test_weapon.instance_id:
			failures.append("重启载入后背包或装备不一致")
		elif not reload_manager.all_ids_unique():
			failures.append("重载后实例ID不唯一")
		reload_manager.free()
	if failures.is_empty():
		print("EQUIPMENT_TEST_PASS elapsed=%.1f kills=%d drops=%d unique_ids=true slots=36 save_reload=true" % [battle.elapsed, battle.kills, inventory.items.size()])
	else:
		for failure in failures:
			push_error("EQUIPMENT_TEST_FAIL: " + failure)
	Engine.time_scale = 1.0
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_persistence_write() -> void:
	var item: Dictionary = battle.equipment_generator.generate(12, "跨进程存档测试", "orange", "main_hand")
	var added: bool = battle.inventory.add_item(item, false)
	var equipped: bool = battle.inventory.equip_item("pikachu", item.instance_id, "main_hand")
	var saved: bool = battle.inventory.save_to_disk()
	var passed: bool = added and equipped and saved and not item.get("affixes", []).is_empty()
	if passed:
		print("PERSISTENCE_WRITE_PASS id=%s affixes=%d" % [item.instance_id, item.affixes.size()])
	else:
		push_error("PERSISTENCE_WRITE_FAIL")
	get_tree().quit(0 if passed else 1)

func finish_persistence_read() -> void:
	var equipped_id: String = battle.inventory.equipped.get("pikachu", {}).get("main_hand", "")
	var item = battle.inventory.find_item(equipped_id)
	var passed: bool = item != null and not equipped_id.is_empty() and not item.get("affixes", []).is_empty() and battle.inventory.all_ids_unique()
	if passed:
		print("PERSISTENCE_READ_PASS id=%s items=%d affixes=%d" % [equipped_id, battle.inventory.items.size(), item.affixes.size()])
	else:
		push_error("PERSISTENCE_READ_FAIL")
	get_tree().quit(0 if passed else 1)

