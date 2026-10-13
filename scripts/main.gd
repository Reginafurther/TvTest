extends Node

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const InventoryUIScript = preload("res://scripts/inventory_ui.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const V03UIScript = preload("res://scripts/v03_ui.gd")
const TutorialUIScript = preload("res://scripts/tutorial_ui.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")

var battle: Node2D
var stats_label: Label
var state_label: Label
var log_label: RichTextLabel
var cards: HBoxContainer
var help_label: Label
var inventory_ui
var backpack_button: Button
var v03_ui
var tutorial_ui
var world_label: Label
var gold_label: Label
var loot_notice: Label
var loot_notice_time := 0.0
var objective_label: Label
var settings_button: Button

func _ready() -> void:
	build_background()
	battle = BattleControllerScript.new()
	battle.position = Vector2(180, 136)
	add_child(battle)
	build_ui()
	battle.stats_changed.connect(update_stats)
	battle.party_changed.connect(update_party)
	battle.log_message.connect(add_log)
	battle.battle_state_changed.connect(update_state)
	inventory_ui = InventoryUIScript.new()
	add_child(inventory_ui)
	inventory_ui.setup(battle)
	v03_ui = V03UIScript.new()
	add_child(v03_ui)
	v03_ui.setup(battle)
	v03_ui.inventory_ui = inventory_ui
	inventory_ui.feature_ui = v03_ui
	tutorial_ui = TutorialUIScript.new()
	add_child(tutorial_ui)
	tutorial_ui.setup(battle, inventory_ui, v03_ui)
	battle.world_changed.connect(_update_world)
	battle.progression.changed.connect(_update_gold)
	battle.progression.changed.connect(_update_objective)
	battle.loot_obtained.connect(_show_loot)
	_update_world(battle.current_map_id)
	_update_gold()
	_update_objective()
	update_party(battle.heroes)
	add_log("四人小队已进入青草渡口，自动战斗开始")
	if "--v031-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v031_test")
	elif "--v03-persist-write" in OS.get_cmdline_user_args():
		finish_v03_persist_write()
	elif "--v03-persist-read" in OS.get_cmdline_user_args():
		finish_v03_persist_read()
	elif "--v03-test" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
		get_tree().create_timer(20.0).timeout.connect(finish_v03_test)
	elif "--persistence-write" in OS.get_cmdline_user_args():
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
	if loot_notice_time > 0:
		loot_notice_time -= _delta
		if loot_notice_time <= 0: loot_notice.visible = false
	if Input.is_key_pressed(KEY_R) and battle.game_over:
		battle.restart()

func build_background() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("#16232A")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = Vector2(1440, 800)
	add_child(backdrop)

func build_ui() -> void:
	var title := Label.new()
	title.text = "万界冒险团 V0.31"
	title.position = Vector2(18, 10)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#FFF2B5"))
	add_child(title)

	state_label = Label.new()
	state_label.text = "● 自动战斗中"
	state_label.position = Vector2(435, 22)
	state_label.add_theme_color_override("font_color", Color("#82EEA6"))
	add_child(state_label)

	stats_label = Label.new()
	stats_label.text = "击败 0  ·  第 1 波  ·  00:00"
	stats_label.position = Vector2(985, 22)
	stats_label.size = Vector2(300, 30)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats_label.add_theme_font_size_override("font_size", 17)
	add_child(stats_label)

	backpack_button = Button.new()
	backpack_button.text = "背包 / 装备  B"
	backpack_button.position = Vector2(17, 70)
	backpack_button.size = Vector2(150, 42)
	backpack_button.pressed.connect(_on_backpack_pressed)
	add_child(backpack_button)

	var footer := ColorRect.new()
	footer.position = Vector2(0, 680)
	footer.size = Vector2(1440, 120)
	footer.color = Color("#101B22")
	add_child(footer)

	cards = HBoxContainer.new()
	cards.position = Vector2(18, 694)
	cards.size = Vector2(850, 92)
	cards.add_theme_constant_override("separation", 8)
	add_child(cards)

	log_label = RichTextLabel.new()
	log_label.position = Vector2(884, 695)
	log_label.size = Vector2(536, 90)
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	add_child(log_label)

	help_label = Label.new()
	help_label.text = "左键地图：集结点    空格：暂停    B：背包    R：全灭重开"
	help_label.position = Vector2(184, 655)
	help_label.add_theme_color_override("font_color", Color("#E8F2DF"))
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	help_label.add_theme_constant_override("outline_size", 4)
	add_child(help_label)

	world_label = Label.new()
	world_label.position = Vector2(18, 43)
	world_label.add_theme_font_size_override("font_size", 17)
	add_child(world_label)
	gold_label = Label.new()
	gold_label.position = Vector2(1210, 52)
	gold_label.add_theme_color_override("font_color", Color("#FFE299"))
	add_child(gold_label)
	settings_button = Button.new()
	settings_button.text = "设置 / 引导"
	settings_button.position = Vector2(1275, 70)
	settings_button.size = Vector2(145, 42)
	settings_button.pressed.connect(_open_settings)
	add_child(settings_button)
	objective_label = Label.new()
	objective_label.position = Vector2(1250, 160)
	objective_label.size = Vector2(176, 250)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_color_override("font_color", Color("#BBD9E4"))
	add_child(objective_label)
	loot_notice = Label.new()
	loot_notice.position = Vector2(470, 142)
	loot_notice.size = Vector2(480, 42)
	loot_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_notice.add_theme_font_size_override("font_size", 22)
	loot_notice.visible = false
	add_child(loot_notice)

func _update_world(map_id: String) -> void:
	var data: Dictionary = battle.worlds_config.maps.get(map_id, {})
	world_label.text = "世界：%s    地图：%s  · Lv.%d" % [data.get("world", ""), data.get("name", ""), data.get("level", 1)]

func _update_gold() -> void:
	gold_label.text = "金币 %d" % battle.progression.gold

func _update_objective() -> void:
	if objective_label == null: return
	var p = battle.progression
	if p.guide_finished:
		objective_label.text = "当前目标\n\n挂机击败怪物\n自动拾取装备与材料\n打开背包穿戴装备\n招募并更换伙伴\n挑战传奇 Boss"
	else:
		var step: int = clampi(p.guide_step, 0, 5)
		objective_label.text = "当前目标\n\n" + TutorialUIScript.STEPS[step][0] + "\n\n" + TutorialUIScript.STEPS[step][1]

func _show_loot(item: Dictionary) -> void:
	var quality: Dictionary = battle.equipment_config.qualities.get(item.quality, {})
	if int(quality.get("rank", 0)) < 2: return
	loot_notice.text = "★ 自动拾取：%s" % item.name
	loot_notice.add_theme_color_override("font_color", Color(quality.get("color", "FFFFFF")))
	loot_notice.visible = true
	loot_notice_time = 3.5

func _open_settings() -> void:
	var popup := ConfirmationDialog.new()
	popup.title = "设置与新手引导"
	popup.dialog_text = "游戏自动存档。按空格暂停或继续。\n点击“确定”可从头重新查看新手引导，不会重置存档。"
	popup.confirmed.connect(func(): battle.progression.restart_guide(); popup.queue_free())
	popup.canceled.connect(func(): popup.queue_free())
	add_child(popup)
	popup.popup_centered()

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
		panel.custom_minimum_size = Vector2(207, 85)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#21333C")
		style.border_color = Color(unit.actor_data.get("color", "FFFFFF"))
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var portrait: Texture2D = ArtCatalogScript.texture("portraits", unit.actor_id)
		if portrait != null:
			var avatar := TextureRect.new()
			avatar.texture = portrait
			avatar.custom_minimum_size = Vector2(45, 45)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(avatar)
		else:
			var avatar_placeholder := Label.new()
			avatar_placeholder.text = unit._name().substr(0, 1)
			avatar_placeholder.custom_minimum_size = Vector2(38, 45)
			avatar_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			avatar_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			avatar_placeholder.add_theme_font_size_override("font_size", 22)
			avatar_placeholder.add_theme_color_override("font_color", Color(unit.actor_data.get("color", "FFFFFF")))
			row.add_child(avatar_placeholder)
		var label := Label.new()
		label.text = "%s  ·  %s\nHP %d/%d  ◆%d  ☠%s\n攻 %.0f  防 %.0f  %s" % [unit._name(), unit.actor_data.get("role", ""), unit.hp, unit.max_hp, int(unit.shield), "是" if unit.poison_time > 0 else "无", unit.attack, unit.defense, unit._skill_name()]
		label.add_theme_font_size_override("font_size", 13)
		row.add_child(label)
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

func finish_v03_test() -> void:
	var failures: Array[String] = []
	if battle.kills <= 0 or battle.stats_snapshot().actors.is_empty():
		failures.append("真实战斗统计或挂机战斗未产生数据")
	# Independent world pools and clean target rebuild.
	if not battle.switch_map("viridian_forest") or battle.current_map_id != "viridian_forest":
		failures.append("世界切换失败")
	for enemy in battle.enemies:
		if enemy.actor_id not in ["zubat", "forest_bug"]: failures.append("常青森林敌人池串线")
	# Recruitment is unique and party changes retain the old actor's equipment mapping.
	var p = battle.progression
	var first_recruit: String = p.use_recruit_token(battle.worlds_config.recruitment.starter_pool, battle.equipment_generator.rng)
	var second_recruit: String = p.use_recruit_token(battle.worlds_config.recruitment.starter_pool, battle.equipment_generator.rng)
	if first_recruit.is_empty() or not second_recruit.is_empty() or p.roster.count(first_recruit) != 1:
		failures.append("招募令唯一性失败")
	var old_equipment: Dictionary = battle.inventory.equipped["zhao_yun"].duplicate(true)
	p.set_party_member(0, first_recruit)
	battle.rebuild_party()
	if battle.get_hero(first_recruit) == null or battle.inventory.equipped["zhao_yun"] != old_equipment:
		failures.append("编队切换或装备归属失败")
	# Dismantle and reroll are transactional.
	p.add_material("salvage_dust", 200)
	var junk: Dictionary = battle.equipment_generator.generate(8, "V0.3测试", "purple", "helmet")
	battle.inventory.add_item(junk, false)
	var before_count: int = battle.inventory.items.size()
	var reward: int = battle.crafting.dismantle(junk.instance_id)
	if reward <= 0 or battle.inventory.items.size() != before_count - 1:
		failures.append("分解事务失败")
	var reroll_item: Dictionary = battle.equipment_generator.generate(8, "V0.3测试", "orange", "main_hand")
	battle.inventory.add_item(reroll_item, false)
	var same_id: String = reroll_item.instance_id
	var dust_before: int = p.materials.salvage_dust
	var pending: Dictionary = battle.crafting.begin_reroll(same_id, 0)
	if pending.is_empty() or not battle.crafting.resolve_reroll(true) or reroll_item.instance_id != same_id or p.materials.salvage_dust >= dust_before:
		failures.append("重铸材料或实例安全失败")
	# Equip four special mechanisms and fire controlled real combat events.
	var hero = battle.heroes[0]
	var slots := ["main_hand", "off_hand", "helmet", "armor"]
	var effects := ["crit_lightning", "thorn_reflect", "poison_spread", "shield_burst"]
	for i in range(4):
		var item: Dictionary = battle.equipment_generator.generate(10, "特效测试", "orange", slots[i])
		item.special_effects = [effects[i]]
		battle.inventory.add_item(item, false)
		battle.inventory.equip_item(hero.actor_id, item.instance_id, slots[i])
	hero = battle.get_hero(hero.actor_id)
	var enemy = battle.enemies[0]
	battle.special_config.effects.crit_lightning.chance = 1.0
	battle.on_damage(hero, enemy, 10.0, {"kind": "basic", "critical": true, "allow_triggers": true})
	hero.add_shield(1.0)
	hero.take_damage(300.0, enemy, false, {"kind": "basic", "allow_triggers": true})
	var poisoned = battle.enemies[1] if battle.enemies.size() > 1 else enemy
	poisoned.apply_poison(5.0, 5.0, hero, 0)
	poisoned.take_damage(99999.0, hero, false, {"kind": "skill", "allow_triggers": true})
	for effect in effects:
		if int(battle.trigger_counts[effect]) <= 0: failures.append("特殊词条未触发：" + effect)
	if int(battle.trigger_counts.thorn_reflect) > 2 or int(battle.trigger_counts.poison_spread) > 1:
		failures.append("特殊词条出现递归连锁")
	# Strategy conditions alter the actual skill gate.
	var preset: Dictionary = p.strategy_presets[p.active_strategy]
	preset.enemy_count = 99
	if battle.strategy_allows(hero): failures.append("技能敌人数阈值未生效")
	preset.enemy_count = 1
	# Both boss first clears unlock exactly once; repeats pay material instead.
	for boss_id in ["lu_bu", "mewtwo"]:
		battle.start_boss(boss_id)
		var boss = battle.enemies[0]
		boss.take_damage(999999.0, battle.heroes[0], false, {"kind": "skill", "allow_triggers": false})
		var actor_id: String = battle.worlds_config.bosses[boss_id].unlock_actor
		if actor_id not in p.roster or not p.boss_first_clear[boss_id]: failures.append("Boss首胜解锁失败：" + boss_id)
		var material_id: String = battle.worlds_config.bosses[boss_id].repeat_material
		var material_before: int = p.materials[material_id]
		battle.resolve_boss_victory(boss_id)
		if p.roster.count(actor_id) != 1 or int(p.materials[material_id]) <= material_before: failures.append("Boss重复奖励失败：" + boss_id)
	if not battle.inventory.all_ids_unique() or not p.save_to_disk() or not battle.inventory.save_to_disk():
		failures.append("保存或实例唯一性失败")
	if failures.is_empty():
		print("V03_TEST_PASS worlds=2 roster=%d party=4 specials=4 bosses=2 stats=true crafting=true save=true" % p.roster.size())
	else:
		for failure in failures: push_error("V03_TEST_FAIL: " + failure)
	Engine.time_scale = 1.0
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v03_persist_write() -> void:
	var p = battle.progression
	p.add_material("three_kingdoms_token", 77)
	if "gengar" not in p.roster: p.roster.append("gengar")
	p.party[0] = "gengar"
	p.strategy_presets["稳健"].enemy_count = 3
	var passed: bool = p.save_to_disk()
	print("V03_PERSIST_WRITE_PASS roster=%d party0=%s" % [p.roster.size(), p.party[0]]) if passed else push_error("V03_PERSIST_WRITE_FAIL")
	get_tree().quit(0 if passed else 1)

func finish_v03_persist_read() -> void:
	var p = battle.progression
	var passed: bool = int(p.materials.three_kingdoms_token) == 77 and "gengar" in p.roster and p.party[0] == "gengar" and int(p.strategy_presets["稳健"].enemy_count) == 3
	print("V03_PERSIST_READ_PASS roster=%d party0=%s material=%d" % [p.roster.size(), p.party[0], p.materials.three_kingdoms_token]) if passed else push_error("V03_PERSIST_READ_FAIL")
	get_tree().quit(0 if passed else 1)

func finish_v031_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	if p.guide_finished or p.guide_step != 0 or not tutorial_ui.panel.visible:
		failures.append("新存档引导未从真实初始状态开始")
	if battle.is_paused:
		failures.append("非模态引导阻止了自动战斗")
	tutorial_ui.action_button.pressed.emit()
	if not v03_ui.panel.visible or v03_ui.current_view != "recruit":
		failures.append("新手引导前往按钮无效")
	v03_ui.close_panel()
	var recruited: String = p.use_recruit_token(battle.worlds_config.recruitment.starter_pool, battle.equipment_generator.rng)
	tutorial_ui.advance_from_state()
	if recruited.is_empty() or p.guide_step != 1:
		failures.append("初始招募未推进引导")
	var enemy = battle.enemies[0]
	enemy.take_damage(99999.0, battle.heroes[0], false, {"kind": "skill", "allow_triggers": false})
	tutorial_ui.advance_from_state()
	if p.guide_step != 2 or battle.kills < 1:
		failures.append("真实击杀未推进自动战斗步骤")
	var before_drop: int = battle.inventory.items.size()
	battle.roll_equipment_drop(battle.enemies[0])
	tutorial_ui.advance_from_state()
	if p.guide_step != 3 or battle.inventory.items.size() <= before_drop:
		failures.append("真实掉落未推进装备步骤")
	var item: Dictionary = battle.inventory.items.back()
	if not battle.inventory.equip_item("zhao_yun", item.instance_id, item.slot):
		failures.append("装备穿戴失败")
	tutorial_ui.advance_from_state()
	if p.guide_step != 4:
		failures.append("穿戴状态未推进引导")
	var next_actor := "zhang_fei" if "zhang_fei" not in p.roster else "dian_wei"
	var cost: Array = battle.worlds_config.recruitment.costs[next_actor]
	p.add_material(cost[0], int(cost[1]))
	if not p.exchange_actor(next_actor, cost[0], int(cost[1])):
		failures.append("定向招募失败")
	tutorial_ui.advance_from_state()
	if p.guide_step != 5:
		failures.append("伙伴增加未推进引导")
	p.set_party_member(0, next_actor)
	battle.rebuild_party()
	tutorial_ui.advance_from_state()
	if not p.guide_finished or tutorial_ui.panel.visible:
		failures.append("编队后引导未完成")
	for view in ["party", "recruit", "world", "boss", "craft", "strategy", "stats"]:
		if not v03_ui.toolbar_buttons.has(view):
			failures.append("缺少功能按钮：" + view)
		else:
			v03_ui.toolbar_buttons[view].pressed.emit()
			if not v03_ui.panel.visible or v03_ui.current_view != view:
				failures.append("功能入口未打开：" + view)
			v03_ui.close_panel()
	v03_ui._preview_boss("lu_bu")
	if "推荐等级" not in v03_ui.boss_dialog.dialog_text:
		failures.append("Boss挑战前信息缺失")
	v03_ui.boss_dialog.hide()
	backpack_button.pressed.emit()
	settings_button.pressed.emit()
	var settings_open := false
	for node in get_children():
		if node is ConfirmationDialog and node.title == "设置与新手引导":
			settings_open = true
			node.hide()
			node.queue_free()
	if not settings_open: failures.append("设置入口未打开")
	if not inventory_ui.panel.visible or inventory_ui.actor_select.item_count != p.roster.size():
		failures.append("背包入口或角色选择未更新")
	backpack_button.pressed.emit()
	if ArtCatalogScript.texture("portraits", "missing_actor") != null or ArtCatalogScript.texture("maps_ground", "missing_map") != null:
		failures.append("缺少美术资源未安全回退")
	ArtCatalogScript._config = {"portraits": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}, "units": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}, "equipment_icons": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}, "function_icons": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}, "maps_ground": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}, "maps_decor": {"fixture": "res://tests/fixtures/replaceable_texture.svg"}}
	for group in ["portraits", "units", "equipment_icons", "function_icons", "maps_ground", "maps_decor"]:
		if ArtCatalogScript.texture(group, "fixture") == null:
			failures.append("美术配置替换加载失败：" + group)
	ArtCatalogScript.reload()
	p.restart_guide()
	tutorial_ui.advance_from_state()
	if not tutorial_ui.panel.visible or p.guide_step != 0:
		failures.append("无法重新查看引导")
	for index in range(6):
		p.set_guide_step(index + 1)
	if not p.guide_finished:
		failures.append("回顾模式无法手动完成")
	p.restart_guide()
	p.skip_guide()
	if tutorial_ui.panel.visible or not p.guide_skipped:
		failures.append("无法跳过引导")
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or not reload_progress.guide_finished or not reload_progress.guide_skipped or reload_progress.gold != p.gold or reload_progress.party != p.party:
		failures.append("引导、金币或编队在重新载入后丢失")
	reload_progress.free()
	var reload_inventory = InventoryManagerScript.new()
	reload_inventory.setup(battle.equipment_config)
	if not reload_inventory.load_from_disk() or reload_inventory.get_equipped_item("zhao_yun", item.slot) == null:
		failures.append("新手穿戴装备在重新载入后丢失")
	reload_inventory.free()
	var legacy_path := "user://v031_legacy_fixture.json"
	var old_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"version": "0.3", "roster": ["zhao_yun", "liu_bei", "pikachu", "snorlax", "gengar"], "party": ["gengar", "liu_bei", "pikachu", "snorlax"], "materials": {"pokemon_token": 17}}))
	old_file.close()
	var legacy = ProgressionManagerScript.new()
	legacy.save_path = legacy_path
	if not legacy.load_from_disk() or not legacy.guide_finished or legacy.party[0] != "gengar" or legacy.materials.pokemon_token != 17 or legacy.gold != 0:
		failures.append("旧版存档迁移失败")
	legacy.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	if failures.is_empty():
		print("V031_TEST_PASS guide=6 skip_replay=true menus=8 old_save=true art_fallback=true inventory=true")
	else:
		for failure in failures: push_error("V031_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


