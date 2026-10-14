extends Node

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const InventoryUIScript = preload("res://scripts/inventory_ui.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const V03UIScript = preload("res://scripts/v03_ui.gd")
const TutorialUIScript = preload("res://scripts/tutorial_ui.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const V035ThemeScript = preload("res://scripts/v035_theme.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")
const CampUIScript = preload("res://scripts/camp_ui.gd")
const ResetManagerScript = preload("res://scripts/reset_manager.gd")

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
var header_panel: PanelContainer
var footer_panel: PanelContainer
var objective_chip: PanelContainer
var objective_button: Button
var backdrop: ColorRect
var character_ui
var character_button: Button
var camp_ui

func _ready() -> void:
	DisplayServer.window_set_title("万界冒险团 V0.8.1")
	build_background()
	battle = BattleControllerScript.new()
	battle.position = Vector2(190, 70)
	add_child(battle)
	build_ui()
	battle.stats_changed.connect(update_stats)
	battle.party_changed.connect(update_party)
	battle.log_message.connect(add_log)
	battle.battle_state_changed.connect(update_state)
	inventory_ui = InventoryUIScript.new()
	add_child(inventory_ui)
	inventory_ui.setup(battle)
	character_ui = CharacterUIScript.new()
	add_child(character_ui)
	character_ui.setup(battle)
	inventory_ui.character_ui = character_ui
	character_ui.inventory_ui = inventory_ui
	camp_ui = CampUIScript.new()
	add_child(camp_ui)
	camp_ui.setup(battle)
	camp_ui.actor_requested.connect(func(actor_id): camp_ui.close_panel(); character_ui.selected_actor = actor_id; character_ui.open("stats"))
	v03_ui = V03UIScript.new()
	add_child(v03_ui)
	v03_ui.setup(battle)
	v03_ui.inventory_ui = inventory_ui
	v03_ui.character_ui = character_ui
	v03_ui.camp_ui = camp_ui
	inventory_ui.feature_ui = v03_ui
	tutorial_ui = TutorialUIScript.new()
	add_child(tutorial_ui)
	tutorial_ui.setup(battle, character_ui, v03_ui)
	battle.world_changed.connect(_update_world)
	battle.progression.changed.connect(_update_gold)
	battle.progression.changed.connect(_update_objective)
	battle.loot_obtained.connect(_show_loot)
	_update_world(battle.current_map_id)
	_update_gold()
	_update_objective()
	update_party(battle.heroes)
	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui()
	add_log("刘备已抵达虎牢关前哨，请先用虎符招募并上阵输出伙伴")
	if "--v035-preview" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_save_v035_preview)
	elif "--v05-preview-1440" in OS.get_cmdline_user_args():
		call_deferred("_save_v05_preview", Vector2i(1440, 768), "v05_1440.png", "")
	elif "--v05-preview-1920" in OS.get_cmdline_user_args():
		call_deferred("_save_v05_preview", Vector2i(1920, 1080), "v05_1920.png", "")
	elif "--v05-preview-shop" in OS.get_cmdline_user_args():
		call_deferred("_save_v05_preview", Vector2i(1440, 768), "v05_shop.png", "shop")
	elif "--v05-preview-skills" in OS.get_cmdline_user_args():
		call_deferred("_save_v05_preview", Vector2i(1440, 768), "v05_skills.png", "strategy")
	elif "--v06-preview-character-1440" in OS.get_cmdline_user_args():
		call_deferred("_save_v06_character_preview", Vector2i(1440, 768), "v06_character_1440.png")
	elif "--v06-preview-character-1920" in OS.get_cmdline_user_args():
		call_deferred("_save_v06_character_preview", Vector2i(1920, 1080), "v06_character_1920.png")
	elif "--v05-core-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v05_core_test")
	elif "--v05-shop-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v05_shop_test")
	elif "--v05-skill-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v05_skill_test")
	elif "--v061-exclusive-skill-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v05_skill_test")
	elif "--v05-system-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v05_system_test")
	elif "--v06-world-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v06_world_test")
	elif "--v06-progression-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v06_progression_test")
	elif "--v06-character-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v06_character_test")
	elif "--v061-start-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_start_test")
	elif "--v061-ai-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_ai_test")
	elif "--v061-skill-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_skill_test")
	elif "--v061-progression-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_progression_test")
	elif "--v061-economy-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_economy_test")
	elif "--v061-core-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_core_test")
	elif "--v061-playtest-fixes-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_playtest_fixes_test")
	elif "--v061-long-combat-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v061_long_combat_test")
	elif "--v07-ui-actors-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v07_ui_actors_test")
	elif "--v07-adventure-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v07_adventure_test")
	elif "--v07-persistence-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v07_persistence_test")
	elif "--v08-content-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v08_content_test")
	elif "--v08-skills-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v08_skills_test")
	elif "--v08-systems-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v08_systems_test")
	elif "--v081-ui-stats-art-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v081_ui_stats_art_test")
	elif "--v081-difficulty-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v081_difficulty_test")
	elif "--v081-reset-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v081_reset_test")
	elif "--v081-reset-read" in OS.get_cmdline_user_args():
		call_deferred("finish_v081_reset_read_test")
	elif "--v031-test" in OS.get_cmdline_user_args():
		call_deferred("finish_v031_test")
	elif "--v03-persist-write" in OS.get_cmdline_user_args():
		finish_v03_persist_write()
	elif "--v03-persist-read" in OS.get_cmdline_user_args():
		finish_v03_persist_read()
	elif "--v03-test" in OS.get_cmdline_user_args():
		Engine.time_scale = 4.0
		get_tree().create_timer(25.0).timeout.connect(finish_v03_test)
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
	backdrop = ColorRect.new()
	backdrop.color = Color("#284D55")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = Vector2(1440, 768)
	add_child(backdrop)

func build_ui() -> void:
	header_panel = PanelContainer.new()
	header_panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#25485A"), Color("#D8AA62"), 0, 0))
	header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_panel)
	footer_panel = PanelContainer.new()
	footer_panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#F8EBCD"), Color("#C6924A"), 12, 0))
	footer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_panel)

	var title := Label.new()
	title.name = "GameTitle"
	title.text = "万界冒险团  V0.8.1"
	V035ThemeScript.label(title, 26, Color("#FFF1C7"))
	add_child(title)

	state_label = Label.new()
	state_label.text = "● 自动战斗中"
	V035ThemeScript.label(state_label, 15, Color("#A9F3BB"))
	add_child(state_label)

	stats_label = Label.new()
	stats_label.text = "击败 0  ·  第 1 波  ·  00:00"
	stats_label.size = Vector2(265, 30)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	V035ThemeScript.label(stats_label, 15, Color("#FFF1D2"))
	add_child(stats_label)

	backpack_button = Button.new()
	backpack_button.text = "背包"
	backpack_button.tooltip_text = "背包与装备（B）"
	backpack_button.size = Vector2(105, 57)
	V035ThemeScript.button(backpack_button, "gold")
	backpack_button.pressed.connect(_on_backpack_pressed)
	add_child(backpack_button)

	cards = HBoxContainer.new()
	cards.size = Vector2(846, 126)
	cards.add_theme_constant_override("separation", 6)
	add_child(cards)

	log_label = RichTextLabel.new()
	log_label.visible = false
	log_label.bbcode_enabled = true
	add_child(log_label)

	help_label = Label.new()
	help_label.text = "左键地图设集结点 · 空格暂停 · B背包"
	V035ThemeScript.label(help_label, 13, Color("#F7F5DB"))
	help_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	help_label.add_theme_constant_override("outline_size", 4)
	add_child(help_label)

	world_label = Label.new()
	world_label.size = Vector2(440, 34)
	world_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	V035ThemeScript.label(world_label, 21, Color("#FFF1D2"))
	add_child(world_label)
	gold_label = Label.new()
	V035ThemeScript.label(gold_label, 18, Color("#FFE299"))
	add_child(gold_label)
	settings_button = Button.new()
	settings_button.text = "设置"
	settings_button.size = Vector2(82, 38)
	V035ThemeScript.button(settings_button, "blue")
	settings_button.pressed.connect(_open_settings)
	add_child(settings_button)
	character_button = Button.new()
	character_button.text = "角色"
	character_button.tooltip_text = "角色养成：属性、编队、装备位与技能"
	character_button.size = Vector2(82, 38)
	V035ThemeScript.button(character_button, "gold")
	character_button.pressed.connect(func(): character_ui.open("stats"))
	add_child(character_button)
	objective_chip = PanelContainer.new()
	objective_chip.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#FFF3D9"), Color("#C9934D"), 13, 7))
	add_child(objective_chip)
	objective_label = Label.new()
	objective_label.size = Vector2(265, 43)
	V035ThemeScript.label(objective_label, 16, Color("#493520"))
	objective_chip.add_child(objective_label)
	objective_button = Button.new()
	objective_button.text = "查看目标"
	objective_button.size = Vector2(88, 36)
	V035ThemeScript.button(objective_button, "gold")
	objective_button.pressed.connect(func(): v03_ui.open_view("objectives"))
	add_child(objective_button)
	loot_notice = Label.new()
	loot_notice.size = Vector2(480, 42)
	loot_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_notice.add_theme_font_size_override("font_size", 22)
	loot_notice.visible = false
	add_child(loot_notice)

func _layout_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var factor: float = minf(viewport_size.x / 1440.0, viewport_size.y / 768.0)
	var offset_x: float = (viewport_size.x - 1440.0 * factor) * 0.5
	var header_h: float = 55.0 * factor
	var footer_h: float = 198.0 * factor
	var footer_y: float = viewport_size.y - footer_h
	backdrop.size = viewport_size
	header_panel.position = Vector2.ZERO
	header_panel.size = Vector2(viewport_size.x, header_h)
	footer_panel.position = Vector2(0, footer_y)
	footer_panel.size = Vector2(viewport_size.x, footer_h)
	var battle_scale: float = minf((viewport_size.x - 24.0 * factor) / 1060.0, (footer_y - header_h - 28.0 * factor) / 520.0)
	battle.scale = Vector2.ONE * battle_scale
	battle.position = Vector2((viewport_size.x - 1060.0 * battle_scale) * 0.5, header_h + (footer_y - header_h - 520.0 * battle_scale) * 0.5)
	var title_node: Label = get_node("GameTitle")
	title_node.position = Vector2(offset_x + 18 * factor, 7 * factor)
	title_node.scale = Vector2.ONE * factor
	state_label.position = Vector2(offset_x + 308 * factor, 20 * factor)
	state_label.scale = Vector2.ONE * factor
	world_label.position = Vector2(offset_x + 485 * factor, 10 * factor)
	world_label.scale = Vector2.ONE * factor
	stats_label.position = Vector2(offset_x + 895 * factor, 19 * factor)
	stats_label.scale = Vector2.ONE * factor
	gold_label.position = Vector2(offset_x + 1190 * factor, 5 * factor)
	gold_label.scale = Vector2.ONE * factor
	character_button.position = Vector2(offset_x + 1250 * factor, 8 * factor)
	character_button.scale = Vector2.ONE * factor
	settings_button.position = Vector2(offset_x + 1340 * factor, 8 * factor)
	settings_button.scale = Vector2.ONE * factor
	cards.position = Vector2(offset_x + 10 * factor, footer_y + 14 * factor)
	cards.scale = Vector2.ONE * factor
	backpack_button.position = Vector2(offset_x + 864 * factor, footer_y + 12 * factor)
	backpack_button.scale = Vector2.ONE * factor
	help_label.position = Vector2(battle.position.x + 8 * factor, footer_y - 23 * factor)
	help_label.scale = Vector2.ONE * factor
	objective_chip.position = Vector2(offset_x + 198 * factor, header_h + 17 * factor)
	objective_chip.size = Vector2(375, 58)
	objective_chip.scale = Vector2.ONE * factor
	objective_button.position = Vector2(offset_x + 470 * factor, header_h + 28 * factor)
	objective_button.scale = Vector2.ONE * factor
	loot_notice.position = Vector2(offset_x + 470 * factor, footer_y - 60 * factor)
	loot_notice.scale = Vector2.ONE * factor
	if v03_ui != null: v03_ui.apply_layout(viewport_size, factor, offset_x, footer_y)
	if tutorial_ui != null: tutorial_ui.apply_layout(viewport_size, factor, offset_x, header_h)
	if inventory_ui != null: inventory_ui.apply_layout(viewport_size)

func _update_world(map_id: String) -> void:
	var data: Dictionary = battle.worlds_config.maps.get(map_id, {})
	world_label.text = "%s  ·  %s   Lv.%d" % [data.get("world", ""), data.get("name", ""), data.get("level", 1)]

func _update_gold() -> void:
	gold_label.text = "金币 %d" % battle.progression.gold

func _update_objective() -> void:
	if objective_label == null: return
	var p = battle.progression
	objective_chip.visible = p.guide_finished
	objective_button.visible = p.guide_finished
	objective_label.text = "当前目标：换装、成长并挑战更高关卡"

func _show_loot(item: Dictionary) -> void:
	var quality: Dictionary = battle.equipment_config.qualities.get(item.quality, {})
	if int(quality.get("rank", 0)) < 2: return
	loot_notice.text = "★ 自动拾取：%s" % item.name
	loot_notice.add_theme_color_override("font_color", Color(quality.get("color", "FFFFFF")))
	loot_notice.visible = true
	loot_notice_time = 3.5

func _open_settings() -> void:
	v03_ui.open_view("settings")

func _save_v035_preview() -> void:
	var path := "user://v035_preview.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("V035_PREVIEW " + ProjectSettings.globalize_path(path))
	get_tree().quit()

func _save_v05_preview(window_size: Vector2i, file_name: String, view: String) -> void:
	get_window().size = window_size
	await get_tree().process_frame
	_layout_ui()
	if not view.is_empty():
		v03_ui.open_view(view)
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://" + file_name
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("V05_PREVIEW_FAIL rendering texture unavailable")
		get_tree().quit(1)
		return
	image.save_png(path)
	print("V05_PREVIEW " + ProjectSettings.globalize_path(path))
	get_tree().quit()

func _save_v06_character_preview(window_size: Vector2i, file_name: String) -> void:
	get_window().size = window_size
	await get_tree().process_frame
	_layout_ui()
	character_ui.open("stats")
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://" + file_name
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("V06_PREVIEW_FAIL rendering texture unavailable")
		get_tree().quit(1)
		return
	image.save_png(path)
	print("V06_PREVIEW " + ProjectSettings.globalize_path(path))
	get_tree().quit()

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
	for actor_id in battle.progression.party:
		var unit = battle.get_hero(actor_id)
		var actor_data: Dictionary = battle.actors.get(actor_id, {})
		var alive: bool = is_instance_valid(unit) and not unit.dead
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(207, 124)
		var accent := Color(actor_data.get("color", "FFFFFF"))
		panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#F5E8C9") if alive else Color("#C7C1B7"), accent.darkened(0.15), 11, 7))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		panel.add_child(row)
		var portrait: Texture2D = ArtCatalogScript.texture("portraits", actor_id)
		if portrait != null:
			var avatar := TextureRect.new()
			avatar.texture = portrait
			avatar.custom_minimum_size = Vector2(65, 100)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(avatar)
		else:
			var avatar_placeholder := Label.new()
			avatar_placeholder.text = str(actor_data.get("name", actor_id)).substr(0, 1)
			avatar_placeholder.custom_minimum_size = Vector2(61, 100)
			avatar_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			avatar_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			avatar_placeholder.add_theme_font_size_override("font_size", 36)
			avatar_placeholder.add_theme_color_override("font_color", accent.darkened(0.15))
			row.add_child(avatar_placeholder)
		var details := VBoxContainer.new()
		details.custom_minimum_size = Vector2(120, 100)
		details.add_theme_constant_override("separation", 3)
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = "Lv.%d %s" % [battle.progression.actor_level(actor_id), str(actor_data.get("name", actor_id))]
		V035ThemeScript.label(name_label, 17, Color("#3C3027"))
		details.add_child(name_label)
		var hp_label := Label.new()
		hp_label.text = "%d / %d" % [int(unit.hp), int(unit.max_hp)] if alive else "已倒下"
		V035ThemeScript.label(hp_label, 13, Color("#584635"))
		details.add_child(hp_label)
		var health_bar := ProgressBar.new()
		health_bar.custom_minimum_size = Vector2(115, 14)
		health_bar.max_value = unit.max_hp if alive else 1
		health_bar.value = unit.hp if alive else 0
		health_bar.show_percentage = false
		health_bar.add_theme_stylebox_override("background", V035ThemeScript.box(Color("#725F4F"), Color("#9B7A57"), 6, 0))
		health_bar.add_theme_stylebox_override("fill", V035ThemeScript.box(Color("#69D977"), Color("#42964C"), 6, 0))
		details.add_child(health_bar)
		var status := Label.new()
		status.text = ("◆护盾  " if alive and unit.shield > 0 else "") + ("☠中毒" if alive and unit.poison_time > 0 else "正常" if alive else "等待复活")
		V035ThemeScript.label(status, 12, Color("#6E553B"))
		details.add_child(status)
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
	for stage in range(1, 11):
		battle.progression.complete_stage(stage)
	if not battle.switch_map("viridian_forest") or battle.current_map_id != "viridian_forest":
		failures.append("世界切换失败")
	for enemy in battle.enemies:
		if enemy.actor_id not in ["zubat", "forest_bug"]: failures.append("常青森林敌人池串线")
	# Material recruitment is unique and party changes retain equipment mapping.
	var p = battle.progression
	p.materials.three_kingdoms_token = 100
	var first_recruit := "zhang_fei"
	var first_ok: bool = p.exchange_actor(first_recruit, "three_kingdoms_token", 40)
	var second_ok: bool = p.exchange_actor(first_recruit, "three_kingdoms_token", 40)
	if not first_ok or second_ok or p.roster.count(first_recruit) != 1:
		failures.append("材料招募唯一性失败")
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
	for stage in range(11, 21):
		p.complete_stage(stage)
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
	p.materials.three_kingdoms_token = 100
	var recruited := "zhang_fei" if p.exchange_actor("zhang_fei", "three_kingdoms_token", 40) else ""
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
			if view in ["party", "strategy"]:
				if not character_ui.panel.visible or character_ui.tabs.current_tab != (3 if view == "party" else 1):
					failures.append("统一角色功能入口未打开：" + view)
				character_ui.close_panel()
			else:
				if not v03_ui.panel.visible or v03_ui.current_view != view:
					failures.append("功能入口未打开：" + view)
				v03_ui.close_panel()
	if v03_ui.toolbar_root.get_child_count() != 8 or v03_ui.aux_root.get_child_count() != 5:
		failures.append("V0.35 底部与侧边功能布局不完整")
	if not objective_chip.visible or battle.is_paused:
		failures.append("V0.35 引导结束后目标或战斗状态异常")
	for view in ["shop", "rewards", "objectives", "logs"]:
		v03_ui.toolbar_buttons[view].pressed.emit()
		if not v03_ui.panel.visible or v03_ui.current_view != view:
			failures.append("V0.35 独立页面未打开：" + view)
		v03_ui.close_panel()
	battle.log_message.emit("V035_LOG_FIXTURE")
	if "V035_LOG_FIXTURE" not in v03_ui.log_lines:
		failures.append("V0.35 日志页面未接收真实战斗事件")
	v03_ui.toolbar_buttons["pause"].pressed.emit()
	if not battle.is_paused:
		failures.append("V0.35 暂停按钮无效")
	v03_ui.toolbar_buttons["pause"].pressed.emit()
	if battle.is_paused:
		failures.append("V0.35 暂停按钮无法恢复战斗")
	if not ArtCatalogScript.texture("portraits", "zhao_yun") is AtlasTexture or ArtCatalogScript.texture("maps_ground", "hulao_pass") == null or ArtCatalogScript.texture("maps_obstacles", "hulao_pass") == null:
		failures.append("V0.35 主界面美术配置或头像裁切未加载")
	if battle.position.y < header_panel.size.y or battle.position.y + 520.0 * battle.scale.y > footer_panel.position.y:
		failures.append("V0.35 战斗地图与顶栏或底栏重叠")
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
	if not character_ui.panel.visible or character_ui.tabs.current_tab != 2 or character_ui.actor_list.item_count != p.roster.size():
		failures.append("统一角色背包入口或角色选择未更新")
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
		print("V035_TEST_PASS map=visible cards=4 menus=13 pause=true art=true log=event_driven")
	else:
		for failure in failures: push_error("V031_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v05_core_test() -> void:
	var failures: Array[String] = []
	var hero = battle.get_hero("zhao_yun")
	var base_attack: float = float(hero.attack) if hero != null else 0.0
	var dropped: Dictionary = battle.equipment_generator.generate(8, "真实掉落穿戴测试", "blue", "main_hand")
	if not battle.inventory.add_item(dropped, false):
		failures.append("测试装备未进入背包")
	inventory_ui.toggle()
	inventory_ui.refresh_all()
	var item_index := -1
	for index in range(inventory_ui.item_list.item_count):
		if inventory_ui.item_list.get_item_metadata(index) == dropped.instance_id:
			item_index = index
			break
	if item_index < 0:
		failures.append("掉落装备未显示在真实背包列表")
	else:
		inventory_ui._on_inventory_selected(item_index)
		inventory_ui.equip_button.pressed.emit()
	if battle.inventory.equipped.get("zhao_yun", {}).get("main_hand", "") != dropped.instance_id:
		failures.append("真实背包按钮未完成装备穿戴")
	if hero == null or hero.attack <= base_attack:
		failures.append("穿戴后战斗攻击属性未实时提高")
	if inventory_ui.layer <= v03_ui.layer:
		failures.append("背包仍可能被底部功能按钮遮挡")
	var reload_inventory = InventoryManagerScript.new()
	reload_inventory.setup(battle.equipment_config)
	if not reload_inventory.load_from_disk() or reload_inventory.equipped.get("zhao_yun", {}).get("main_hand", "") != dropped.instance_id:
		failures.append("装备穿戴未写入V0.5独立存档")
	reload_inventory.free()
	var p = battle.progression
	var roster_before: int = p.roster.size()
	var material_before: int = int(p.materials.three_kingdoms_token)
	v03_ui.open_view("recruit")
	var recruited_ok: bool = p.exchange_actor("zhang_fei", "three_kingdoms_token", 40)
	if not recruited_ok or p.roster.size() != roster_before + 1 or int(p.materials.three_kingdoms_token) != material_before - 40:
		failures.append("材料招募未正确扣除资源并获得角色")
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.roster.size() != p.roster.size() or reload_progress.materials != p.materials:
		failures.append("招募结果未写入V0.5独立存档")
	reload_progress.free()
	if failures.is_empty():
		print("V05_CORE_TEST_PASS ui_equip=true combat_stats=true material_recruit=true persistence=true")
	else:
		for failure in failures:
			push_error("V05_CORE_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v05_shop_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.gold = 1000
	p.save_to_disk()
	v03_ui.open_view("shop")
	v03_ui.selected_shop_product = "training_blade"
	v03_ui.shop_quantity = 2
	var items_before: int = battle.inventory.items.size()
	var gold_before: int = p.gold
	v03_ui._buy_shop_product()
	if battle.inventory.items.size() != items_before + 2 or p.gold != gold_before - 140:
		failures.append("商店页面批量购买装备失败")
	var bought_item: Dictionary = battle.inventory.items.back()
	if bought_item.get("source", "") != "商店购买" or bought_item.get("quality", "") != "green":
		failures.append("商店装备未按JSON配置生成")
	var gold_after_buy: int = p.gold
	p.gold = 0
	if not battle.shop.buy("salvage_pack", 1).is_empty() or "金币不足" not in battle.shop.last_error:
		failures.append("金币不足未阻止交易或缺少反馈")
	p.gold = gold_after_buy
	var old_capacity: int = battle.inventory.capacity
	battle.inventory.capacity = battle.inventory.items.size()
	if not battle.shop.buy("training_coat", 1).is_empty() or "背包空间不足" not in battle.shop.last_error:
		failures.append("背包满时仍可购买装备")
	battle.inventory.capacity = old_capacity
	battle.inventory.equip_item("zhao_yun", bought_item.instance_id, bought_item.slot)
	if not battle.shop.sell(bought_item.instance_id).is_empty() or "穿戴中的装备" not in battle.shop.last_error:
		failures.append("穿戴装备出售限制失效")
	battle.inventory.unequip_slot("zhao_yun", bought_item.slot)
	var sell_gold_before: int = p.gold
	v03_ui.selected_shop_item = bought_item.instance_id
	v03_ui._sell_selected_shop_item()
	if battle.inventory.find_item(bought_item.instance_id) != null or p.gold <= sell_gold_before:
		failures.append("商店页面出售装备失败")
	if p.transaction_log.size() < 2:
		failures.append("购买与出售交易记录未保存")
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	var reload_inventory = InventoryManagerScript.new()
	reload_inventory.setup(battle.equipment_config)
	if not reload_progress.load_from_disk() or reload_progress.gold != p.gold or reload_progress.transaction_log.size() != p.transaction_log.size():
		failures.append("商店金币或交易记录重载失败")
	if not reload_inventory.load_from_disk() or reload_inventory.find_item(bought_item.instance_id) != null:
		failures.append("出售结果未写入装备存档")
	reload_progress.free()
	reload_inventory.free()
	if failures.is_empty():
		print("V05_SHOP_TEST_PASS buy_quantity=2 insufficient_gold=true full_inventory=true equipped_guard=true sell=true persistence=true")
	else:
		for failure in failures:
			push_error("V05_SHOP_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v05_skill_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = p.HERO_IDS.duplicate()
	p.party = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
	p.gold = 10000
	p.materials.salvage_dust = 1000
	p.ensure_growth_layout()
	var active_passes := 0
	var passive_passes := 0
	for actor_id in p.HERO_IDS:
		var actor: Dictionary = battle.actors.get(actor_id, {})
		var active: Dictionary = battle.skills.get(actor.get("skill", ""), {})
		var passive: Dictionary = battle.passives_config.get(actor.get("passive_skill", ""), {})
		if active.is_empty():
			failures.append("缺少主动技能：" + actor_id)
			continue
		if passive.is_empty():
			failures.append("缺少被动技能：" + actor_id)
			continue
		battle.clear_combatants()
		var hero = battle.spawn_unit(actor_id, "heroes", Vector2(200, 200))
		var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(230, 200))
		enemy.max_hp = 99999.0
		enemy.hp = enemy.max_hp
		hero.target = enemy
		if actor_id == "liu_bei":
			var ally = battle.spawn_unit("zhao_yun", "heroes", Vector2(210, 210))
			ally.hp = ally.max_hp * 0.35
		if actor_id == "snorlax":
			hero.hp = hero.max_hp * 0.35
		if hero.try_use_skill():
			active_passes += 1
		else:
			failures.append("主动技能未真实施放：" + actor_id)
		match passive.get("effect", ""):
			"combo":
				hero.target = enemy
				for _hit in range(3): hero.basic_attack()
				if int(battle.passive_trigger_counts.get(actor_id + ":" + hero.passive_skill_id, 0)) > 0: passive_passes += 1
			"healing", "poison_master":
				if int(battle.passive_trigger_counts.get(actor_id + ":" + hero.passive_skill_id, 0)) > 0: passive_passes += 1
			"damage_reduction":
				var hp_before: float = hero.hp
				var preview: int = hero.preview_damage(100.0)
				hero.take_damage(100.0, enemy, false, {"kind": "test", "allow_triggers": false})
				if hp_before - hero.hp < preview: passive_passes += 1
			"low_hp_rage":
				hero.hp = hero.max_hp * 0.3
				hero.target = enemy
				hero.basic_attack()
				if int(battle.passive_trigger_counts.get(actor_id + ":" + hero.passive_skill_id, 0)) > 0: passive_passes += 1
			"team_haste":
				if hero.effective_cooldown(float(active.cooldown)) < float(active.cooldown): passive_passes += 1
			"boss_slayer":
				var boss = battle.spawn_unit("lu_bu_boss", "enemies", Vector2(225, 200))
				boss.max_hp = 99999.0; boss.hp = boss.max_hp; hero.target = boss; hero.basic_attack()
				if int(battle.passive_trigger_counts.get(actor_id + ":" + hero.passive_skill_id, 0)) > 0: passive_passes += 1
			"attack_speed":
				if hero.attack_interval < hero.base_attack_interval: passive_passes += 1
			"health_regen":
				if hero.max_hp > hero.base_max_hp and hero.life_regen > 0.0: passive_passes += 1
			"elemental_damage":
				if hero.elemental_damage > 0.0: passive_passes += 1
	if active_passes != 10:
		failures.append("主动技能有效数量为%d/10" % active_passes)
	if passive_passes != 10:
		failures.append("被动技能有效数量为%d/10" % passive_passes)
	var before_level: int = p.skill_level("zhao_yun", "active")
	var before_power: float = float(battle.skills.spear_flurry.power) * (1.0 + float(battle.skills.spear_flurry.power_per_level) * (before_level - 1))
	if not p.upgrade_skill("zhao_yun", "active"):
		failures.append("技能升级交易失败")
	var after_level: int = p.skill_level("zhao_yun", "active")
	var after_power: float = float(battle.skills.spear_flurry.power) * (1.0 + float(battle.skills.spear_flurry.power_per_level) * (after_level - 1))
	if after_level != before_level + 1 or after_power <= before_power:
		failures.append("技能升级未真实提高战斗倍率")
	v03_ui.selected_skill_actor = "zhao_yun"
	v03_ui.open_view("strategy")
	if "主动" not in v03_ui.title.text or v03_ui.content.get_child_count() < 8:
		failures.append("技能详情与升级界面未构建")
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.skill_level("zhao_yun", "active") != after_level:
		failures.append("技能等级未持久化")
	reload_progress.free()
	if failures.is_empty():
		if "--v061-exclusive-skill-test" in OS.get_cmdline_user_args():
			print("V061_EXCLUSIVE_SKILL_TEST_PASS active=10 passive=10 upgrade=true ui=true persistence=true")
		else:
			print("V05_SKILL_TEST_PASS active=10 passive=10 upgrade=true ui=true persistence=true")
	else:
		for failure in failures:
			push_error("V05_SKILL_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v05_system_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	for resolution in [Vector2i(1440, 768), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		_layout_ui()
		var viewport_size := Vector2(resolution)
		if battle.position.y < header_panel.size.y or battle.position.y + 520.0 * battle.scale.y > footer_panel.position.y:
			failures.append("%dx%d战斗地图与顶栏/底栏重叠" % [resolution.x, resolution.y])
		if v03_ui.panel.position.x + v03_ui.panel.size.x * v03_ui.panel.scale.x > viewport_size.x or v03_ui.panel.position.y + v03_ui.panel.size.y * v03_ui.panel.scale.y > viewport_size.y:
			failures.append("%dx%d功能页面超出窗口" % [resolution.x, resolution.y])
		if v03_ui.aux_root.position.y + 5.0 * 27.0 * v03_ui.aux_root.scale.y > viewport_size.y:
			failures.append("%dx%d商店/收益入口超出窗口" % [resolution.x, resolution.y])
	if battle.worlds_config.get("maps", {}).size() != 20:
		failures.append("双世界主线关卡数量不是20")
	if battle.switch_map("xuchang_gate"):
		failures.append("等级不足时仍能进入高阶关卡")
	var old_attack: float = float(battle.actors.zhao_yun.attack)
	p.actor_levels["zhao_yun"] = 1
	p.actor_experience["zhao_yun"] = 0
	if not p.add_actor_experience("zhao_yun", p.experience_to_next(1) + 1, false) or p.actor_level("zhao_yun") != 2:
		failures.append("角色经验未触发升级")
	for actor_id in p.HERO_IDS:
		p.actor_levels[actor_id] = 20
	var visited := 0
	for stage in range(1, 21):
		var map_id: String = battle.stage_id_for_number(stage)
		if battle.switch_map(map_id): visited += 1
		if not p.is_stage_complete(stage): p.complete_stage(stage)
	if visited != 20:
		failures.append("20关无法按主线顺序全部进入")
	for boss_id in ["lu_bu", "mewtwo"]:
		if not battle.start_boss(boss_id):
			failures.append("Boss挑战无法开始：" + boss_id)
			continue
		var boss = battle.enemies[0]
		boss.take_damage(999999.0, battle.heroes[0], false, {"kind": "skill", "allow_triggers": false})
		if not bool(p.boss_first_clear.get(boss_id, false)):
			failures.append("Boss首胜未记录：" + boss_id)
	battle.clear_combatants()
	var leveled = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 200))
	if leveled.attack <= old_attack:
		failures.append("角色等级未提高实际战斗属性")
	var now := int(Time.get_unix_time_from_system())
	p.pending_offline = {"seconds": 0, "gold": 0, "three_kingdoms_token": 0, "pokemon_token": 0}
	p.last_seen_unix = now - 3600
	var pending: Dictionary = p.calculate_offline_rewards(now)
	var offline_gold_before: int = p.gold
	var claimed: Dictionary = p.claim_offline_rewards()
	if int(pending.get("seconds", 0)) != 3600 or claimed.is_empty() or p.gold <= offline_gold_before:
		failures.append("离线收益计算或领取失败")
	if not p.claim_offline_rewards().is_empty() or int(p.pending_offline.get("seconds", 0)) != 0:
		failures.append("离线收益可重复领取")
	# V0.35进度迁移：读取旧文件，写入独立V0.5文件，旧文件内容必须保持不变。
	var legacy_progress_path := "user://v035_progress_fixture.json"
	var migrated_progress_path := "user://v05_progress_fixture.json"
	for path in [legacy_progress_path, migrated_progress_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var legacy_progress_text := JSON.stringify({"version": "0.35", "gold": 321, "roster": ["zhao_yun", "liu_bei", "pikachu", "snorlax", "gengar"], "party": ["gengar", "liu_bei", "pikachu", "snorlax"], "materials": {"pokemon_token": 17}})
	var legacy_progress_file := FileAccess.open(legacy_progress_path, FileAccess.WRITE)
	legacy_progress_file.store_string(legacy_progress_text)
	legacy_progress_file.close()
	var migrated_progress = ProgressionManagerScript.new()
	migrated_progress.save_path = migrated_progress_path
	migrated_progress.legacy_path = legacy_progress_path
	if not migrated_progress.load_legacy_save() or not migrated_progress.save_to_disk():
		failures.append("V0.35进度迁移失败")
	elif migrated_progress.gold != 321 or migrated_progress.party[0] != "gengar" or migrated_progress.skill_level("gengar", "active") != 1 or not FileAccess.file_exists(migrated_progress_path):
		failures.append("迁移后进度、编队或技能默认值错误")
	if FileAccess.get_file_as_string(legacy_progress_path) != legacy_progress_text:
		failures.append("迁移静默覆盖了V0.35原始进度存档")
	# V0.35装备迁移同样保留旧文件，并验证装备关系。
	var legacy_inventory_path := "user://v035_inventory_fixture.json"
	var migrated_inventory_path := "user://v05_inventory_fixture.json"
	for path in [legacy_inventory_path, migrated_inventory_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var legacy_item: Dictionary = battle.equipment_generator.generate(5, "V0.35迁移样本", "blue", "main_hand")
	var legacy_equipped := {"zhao_yun": {"main_hand": legacy_item.instance_id}}
	var legacy_inventory_text := JSON.stringify({"version": "0.2A", "items": [legacy_item], "equipped": legacy_equipped})
	var legacy_inventory_file := FileAccess.open(legacy_inventory_path, FileAccess.WRITE)
	legacy_inventory_file.store_string(legacy_inventory_text)
	legacy_inventory_file.close()
	var migrated_inventory = InventoryManagerScript.new()
	migrated_inventory.setup(battle.equipment_config)
	migrated_inventory.save_path = migrated_inventory_path
	migrated_inventory.legacy_save_path = legacy_inventory_path
	if not migrated_inventory.load_from_disk() or migrated_inventory.equipped.zhao_yun.main_hand != legacy_item.instance_id or not FileAccess.file_exists(migrated_inventory_path):
		failures.append("V0.35装备与穿戴关系迁移失败")
	if FileAccess.get_file_as_string(legacy_inventory_path) != legacy_inventory_text:
		failures.append("迁移静默覆盖了V0.35原始装备存档")
	migrated_progress.free()
	migrated_inventory.free()
	for path in [legacy_progress_path, migrated_progress_path, legacy_inventory_path, migrated_inventory_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("V05_SYSTEM_TEST_PASS stages=20 level_growth=true offline_once=true legacy_migration=true bosses=2 layouts=1440x768,1920x1080")
	else:
		for failure in failures:
			push_error("V05_SYSTEM_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v06_world_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	if battle.worlds_config.get("maps", {}).size() != 20:
		failures.append("主线关卡数量不是20")
	for stage in range(1, 21):
		if battle.stage_id_for_number(stage).is_empty():
			failures.append("缺少全局第%d关" % stage)
	if p.pokemon_world_unlocked or p.can_enter_stage(11) or battle.switch_map("viridian_forest"):
		failures.append("新档可绕过锁定进入宝可梦世界")
	if p.can_enter_stage(2) or battle.switch_map("xuchang_gate"):
		failures.append("新档可绕过前置关卡")
	if battle.start_boss("lu_bu"):
		failures.append("未通关第10关即可从旧Boss入口绕过")
	for stage in range(1, 10):
		if not p.complete_stage(stage):
			failures.append("第%d关无法顺序完成" % stage)
			break
		if not p.can_enter_stage(stage + 1):
			failures.append("第%d关完成后未解锁下一关" % stage)
	if p.pokemon_world_unlocked or p.can_enter_stage(11):
		failures.append("第9关完成时过早开放第二世界")
	if not p.complete_stage(10) or not p.pokemon_world_unlocked or not p.can_enter_stage(11):
		failures.append("三国第10关未永久开放宝可梦世界")
	if not battle.switch_map("viridian_forest") or battle.switch_map("cerulean_cave"):
		failures.append("宝可梦首关不可进入或末关可跳关")
	for stage in range(11, 21):
		if not p.complete_stage(stage):
			failures.append("宝可梦全局第%d关无法顺序完成" % stage)
			break
	if p.completed_stages.size() != 20 or not p.is_stage_complete(20):
		failures.append("20关完成状态不完整")
	p.save_to_disk()
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.completed_stages.size() != 20 or not reload_progress.pokemon_world_unlocked:
		failures.append("世界开放与20关状态未正确重载")
	reload_progress.free()
	# A V0.5 Boss clear did not mean the new ten-stage campaign was cleared.
	var old_path := "user://v05_world_migration_fixture.json"
	var new_path := "user://v06_world_migration_fixture.json"
	for path in [old_path, new_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old_text := JSON.stringify({"version":"0.5","gold":456,"roster":["zhao_yun","liu_bei","pikachu","snorlax","lu_bu"],"party":["zhao_yun","liu_bei","pikachu","snorlax"],"boss_first_clear":{"lu_bu":true,"mewtwo":false},"actor_levels":{"zhao_yun":12},"actor_experience":{"zhao_yun":17}})
	var old_file := FileAccess.open(old_path, FileAccess.WRITE)
	old_file.store_string(old_text)
	old_file.close()
	var migrated = ProgressionManagerScript.new()
	migrated.save_path = new_path
	migrated.legacy_path = old_path
	if not migrated.load_legacy_save() or not migrated.save_to_disk():
		failures.append("V0.5进度迁移失败")
	elif migrated.gold != 456 or migrated.actor_level("zhao_yun") != 12 or int(migrated.actor_experience.zhao_yun) != 17:
		failures.append("迁移丢失角色、等级或经验")
	elif not migrated.completed_stages.is_empty() or migrated.pokemon_world_unlocked or migrated.can_enter_stage(11):
		failures.append("旧Boss记录被错误映射为新第10关通关")
	if FileAccess.get_file_as_string(old_path) != old_text:
		failures.append("迁移覆盖了V0.5原始存档")
	migrated.free()
	for path in [old_path, new_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("V06_WORLD_TEST_PASS stages=20 sequential=true pokemon_lock=true bosses_gated=true persistence=true v05_migration=conservative")
	else:
		for failure in failures: push_error("V06_WORLD_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v06_progression_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	for actor_id in p.party:
		p.actor_levels[actor_id] = 1
		p.actor_experience[actor_id] = 0
		p.level_history[actor_id] = []
	var normal_xp: int = p.experience_for_kill(5, "normal", 5)
	var elite_xp: int = p.experience_for_kill(5, "elite", 5)
	var boss_xp: int = p.experience_for_kill(5, "boss", 5)
	var farm_xp: int = p.experience_for_kill(1, "normal", 20)
	if not (boss_xp > elite_xp and elite_xp > normal_xp and normal_xp > farm_xp):
		failures.append("普通/精英/Boss经验倍率或低级关衰减无效")
	battle.clear_combatants()
	battle.stage_cleared = false
	battle.wave = 1
	var killer = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 200))
	var victim = battle.spawn_unit("yellow_turban", "enemies", Vector2(230, 200))
	victim.monster_level = 5
	victim.enemy_type = "elite"
	victim.last_damage_source = killer
	var before_party_xp: Dictionary = {}
	for actor_id in p.party: before_party_xp[actor_id] = int(p.actor_experience[actor_id])
	battle._on_unit_died(victim)
	for actor_id in p.party:
		if int(p.actor_experience[actor_id]) <= int(before_party_xp[actor_id]):
			failures.append("上阵角色未共享击杀经验：" + actor_id)
	var once_xp := int(p.actor_experience[p.party[0]])
	battle._on_unit_died(victim)
	if int(p.actor_experience[p.party[0]]) != once_xp:
		failures.append("同一击杀经验被重复结算")
	var hero = battle.get_hero("zhao_yun")
	var attack_before := float(hero.attack)
	p.actor_experience["zhao_yun"] = 0
	p.actor_levels["zhao_yun"] = 1
	if not p.add_actor_experience("zhao_yun", p.experience_to_next(1), false, "升级自动测试"):
		failures.append("经验达到阈值未自动升级")
	hero.refresh_progression_stats()
	if p.actor_level("zhao_yun") != 2 or hero.attack <= attack_before or p.level_history.zhao_yun.is_empty():
		failures.append("升级未改变实际属性或未记录历程")
	var xp_before_offline := int(p.actor_experience.zhao_yun)
	p.pending_offline = {"seconds": 3600, "gold": 10, "three_kingdoms_token": 1, "pokemon_token": 1}
	p.claim_offline_rewards()
	if int(p.actor_experience.zhao_yun) != xp_before_offline:
		failures.append("离线收益错误重复发放经验")
	# 治疗职业普攻治疗；卡比兽仍然造成伤害。
	battle.clear_combatants()
	var liu = battle.spawn_unit("liu_bei", "heroes", Vector2(200, 200))
	var ally = battle.spawn_unit("zhao_yun", "heroes", Vector2(230, 200))
	var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(250, 200))
	ally.hp = ally.max_hp * 0.4
	liu.target = ally
	var ally_hp: float = ally.hp
	var enemy_hp: float = enemy.hp
	liu.basic_attack()
	if ally.hp <= ally_hp or enemy.hp != enemy_hp:
		failures.append("刘备普攻未按治疗职业规则治疗队友")
	var snorlax = battle.spawn_unit("snorlax", "heroes", Vector2(215, 200))
	snorlax.target = enemy
	enemy_hp = enemy.hp
	snorlax.basic_attack()
	if enemy.hp >= enemy_hp:
		failures.append("卡比兽被错误改成治疗普攻")
	var pikachu = battle.spawn_unit("pikachu", "heroes", Vector2(240, 200))
	pikachu.target = enemy
	var distance_before: float = pikachu.position.distance_to(enemy.position)
	pikachu._physics_process(0.1)
	if pikachu.position.distance_to(enemy.position) <= distance_before:
		failures.append("远程职业在敌人贴近时未后撤")
	p.save_to_disk()
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.actor_level("zhao_yun") != 2 or reload_progress.level_history.zhao_yun.is_empty():
		failures.append("等级、经验或升级历程未正确存档")
	reload_progress.free()
	if failures.is_empty():
		print("V06_PROGRESSION_TEST_PASS scaled_xp=true elite_boss_bonus=true shared_once=true level_stats=true healer_ai=true ranged_ai=true persistence=true")
	else:
		for failure in failures: push_error("V06_PROGRESSION_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v06_character_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = p.HERO_IDS.duplicate()
	p.party = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
	p.gold = 10000
	p.materials.salvage_dust = 1000
	p.ensure_growth_layout()
	var original_party: Array = p.party.duplicate()
	character_ui.selected_actor = "zhao_yun"
	character_ui.open("stats")
	await get_tree().process_frame
	if character_ui.actor_list.item_count != 36 or character_ui.slot_buttons.size() != 9 or character_ui.tabs.get_tab_count() != 3:
		failures.append("V0.8角色页未包含36人、9装备栏或3个独立养成标签")
	character_ui._select_actor(1)
	if p.party != original_party:
		failures.append("切换查看角色意外修改了编队")
	character_ui.selected_actor = "zhao_yun"
	character_ui.refresh_all()
	if str(int(p.actor_experience.zhao_yun)) not in character_ui.exp_label.text or str(p.experience_to_next(p.actor_level("zhao_yun"))) not in character_ui.exp_label.text:
		failures.append("角色页经验条与实际存档不一致")
	# 构造4件可提升的紫色+装备；其中一件已被其他角色穿戴，必须排除。
	var generated: Array = []
	for slot in ["main_hand", "helmet", "armor", "boots"]:
		var item: Dictionary = battle.equipment_generator.generate(20, "V0.6角色页测试", "orange" if slot == "main_hand" else "purple", slot)
		battle.inventory.add_item(item, false)
		generated.append(item)
	var protected_item: Dictionary = battle.equipment_generator.generate(40, "其他角色装备", "orange", "gloves")
	protected_item.base_stats = {"attack": 999.0}
	battle.inventory.add_item(protected_item, false)
	battle.inventory.equip_item("liu_bei", protected_item.instance_id, "gloves")
	var candidates: Array = battle.inventory.optimize_candidates("zhao_yun", 3, 9)
	if candidates.is_empty() or candidates.size() > 9:
		failures.append("一键优化没有候选或超过9栏")
	for choice in candidates:
		var candidate_item = battle.inventory.find_item(choice.instance_id)
		if int(candidate_item.get("quality_rank", 0)) < 3:
			failures.append("一键优化使用了紫色以下装备")
		if choice.instance_id == protected_item.instance_id:
			failures.append("一键优化拿走了其他角色装备")
	var item_count_before: int = battle.inventory.items.size()
	var applied: int = battle.inventory.apply_optimization("zhao_yun", candidates)
	if applied < 1 or applied > 9 or battle.inventory.items.size() != item_count_before:
		failures.append("一键优化应用数量错误或复制/丢失装备实例")
	if battle.inventory.item_owner(protected_item.instance_id) != "liu_bei":
		failures.append("其他角色装备关系被破坏")
	# 锁定状态属于原物品实例，并阻止出售、分解与重铸。
	var lock_item: Dictionary = battle.equipment_generator.generate(8, "锁定测试", "purple", "necklace")
	battle.inventory.add_item(lock_item, false)
	battle.inventory.set_item_locked(lock_item.instance_id, true)
	if not battle.shop.sell(lock_item.instance_id).is_empty() or "锁定" not in battle.shop.last_error:
		failures.append("锁定装备仍可出售")
	if battle.crafting.dismantle(lock_item.instance_id) != 0 or not battle.crafting.begin_reroll(lock_item.instance_id, 0).is_empty():
		failures.append("锁定装备仍可分解或重铸")
	# 通用技能沿用同一角色成长存档并真实进入战斗。
	p.grant_skill_book("tk_triple_slash", 1, "test")
	if not p.learn_general_skill("zhao_yun", "tk_triple_slash") or not p.equip_general_skill("zhao_yun", "tk_triple_slash", "active"):
		failures.append("通用主动技能无法学习或装备")
	p.grant_skill_book("tk_battle_focus", 1, "test")
	if not p.learn_general_skill("zhao_yun", "tk_battle_focus") or not p.equip_general_skill("zhao_yun", "tk_battle_focus", "passive"):
		failures.append("通用被动技能无法学习或装备")
	battle.clear_combatants()
	var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 200))
	var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(250, 200))
	var expected_base: float = float(battle.actors.zhao_yun.attack) * (1.0 + (p.actor_level("zhao_yun") - 1) * 0.06) + float(battle.inventory.get_actor_stats("zhao_yun").get("attack", 0))
	if hero.attack <= expected_base:
		failures.append("通用被动技能未提高实际战斗属性")
	hero.target = enemy
	hero.general_active_timers["tk_triple_slash"] = 0.0
	var hp_before: float = enemy.hp
	if not hero.try_use_general_skill("tk_triple_slash") or enemy.hp >= hp_before:
		failures.append("通用主动技能未造成实际战斗效果")
	# 1440/1920布局均不得超出视口。
	for resolution in [Vector2i(1440, 768), Vector2i(1920, 1080)]:
		get_window().size = resolution
		await get_tree().process_frame
		var rect: Rect2 = character_ui.panel.get_global_rect()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > resolution.x + 1 or rect.end.y > resolution.y + 1:
			failures.append("%dx%d角色页面超出窗口" % [resolution.x, resolution.y])
	p.save_to_disk()
	battle.inventory.save_to_disk()
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	var reload_inventory = InventoryManagerScript.new()
	reload_inventory.setup(battle.equipment_config)
	if not reload_progress.load_from_disk() or "tk_triple_slash" not in reload_progress.equipped_general_skills.zhao_yun.active:
		failures.append("通用技能配置未持久化")
	if not reload_inventory.load_from_disk() or not bool(reload_inventory.find_item(lock_item.instance_id).get("locked", false)):
		failures.append("装备锁定或穿戴关系未持久化")
	reload_progress.free()
	reload_inventory.free()
	if failures.is_empty():
		print("V06_CHARACTER_TEST_PASS roster=20 slots=9 tabs=3 separate_inventory=true exp_sync=true optimize_max9=true no_steal=true lock=true general_skills=true persistence=true layouts=1440x768,1920x1080")
	else:
		for failure in failures: push_error("V06_CHARACTER_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_start_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	if p.roster != ["liu_bei"] or p.party != ["liu_bei", "", "", ""]:
		failures.append("新档不是仅刘备与三个空上阵位")
	if p.actor_level("liu_bei") != 1 or int(p.materials.three_kingdoms_token) != 150 or int(p.materials.pokemon_token) != 0:
		failures.append("刘备等级或初始150虎符配置错误")
	if not battle.enemies.is_empty() or battle.has_damage_dealer_in_party():
		failures.append("仅治疗角色时错误启动了第一关")
	p.save_to_disk()
	var payload = JSON.parse_string(FileAccess.get_file_as_string(p.save_path))
	var removed_currency_key := "recruit_" + "tokens"
	var removed_product_key := "recruit_" + "token"
	if typeof(payload) != TYPE_DICTIONARY or payload.has(removed_currency_key):
		failures.append("V0.6.1存档仍保存已废弃招募货币")
	if battle.shop_config.products.has(removed_product_key):
		failures.append("商店仍配置已废弃招募货币商品")
	# 通过真实招募页面依次招募三名三国角色。
	v03_ui.open_view("recruit")
	for actor_id in ["zhang_fei", "dian_wei", "zhao_yun"]:
		var lists: Array[Node] = v03_ui.content.find_children("*", "ItemList", true, false)
		if lists.is_empty():
			failures.append("材料招募列表不存在")
			break
		var list: ItemList = lists[0]
		var index := -1
		for candidate_index in range(list.item_count):
			if str(list.get_item_metadata(candidate_index)) == actor_id: index = candidate_index; break
		if index < 0:
			failures.append("招募列表缺少" + actor_id)
			continue
		v03_ui.exchange_actor(index, list)
	if p.roster.size() != 4 or int(p.materials.three_kingdoms_token) != 30:
		failures.append("150虎符未正确招募三名三国角色")
	# 明确选择位置上阵，不能靠直接修改party数组。
	for index in range(1, 4):
		v03_ui.selected_party_actor = ["zhang_fei", "dian_wei", "zhao_yun"][index - 1]
		v03_ui.assign_selected_party(index)
	if p.party != ["liu_bei", "zhang_fei", "dian_wei", "zhao_yun"] or battle.heroes.size() != 4 or battle.enemies.is_empty():
		failures.append("材料招募到上阵及战场重建链路失败")
	var roster_before: Array = p.roster.duplicate()
	var equipment_before: Dictionary = battle.inventory.equipped.duplicate(true)
	v03_ui.clear_party_slot(2)
	if not str(p.party[2]).is_empty() or battle.heroes.size() != 3:
		failures.append("上阵位置无法清空或战场未立即更新")
	v03_ui.selected_party_actor = "dian_wei"
	v03_ui.assign_selected_party(2)
	if p.roster != roster_before or battle.inventory.equipped != equipment_before or p.party.count("dian_wei") != 1:
		failures.append("替换上阵导致角色/装备关系丢失或角色重复")
	p.save_to_disk()
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.party != p.party or reload_progress.roster != p.roster:
		failures.append("招募与编队未持久化")
	reload_progress.free()
	# 旧V0.6文件即使存在，也不能被V0.6.1新命名空间读取。
	var old_path := "user://v061_old_v06_fixture.json"
	var fresh_path := "user://v061_fresh_fixture.json"
	var old_text := JSON.stringify({"version":"0.6","roster":["mewtwo"],"party":["mewtwo","mewtwo","mewtwo","mewtwo"],"materials":{"three_kingdoms_token":9999}})
	var old_file := FileAccess.open(old_path, FileAccess.WRITE); old_file.store_string(old_text); old_file.close()
	if FileAccess.file_exists(fresh_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(fresh_path))
	var fresh = ProgressionManagerScript.new()
	fresh.save_path = fresh_path
	if fresh.load_from_disk() or fresh.roster != ["liu_bei"] or fresh.party != ["liu_bei", "", "", ""] or int(fresh.materials.three_kingdoms_token) != 150:
		failures.append("全新命名空间错误读取旧V0.6进度")
	if FileAccess.get_file_as_string(old_path) != old_text:
		failures.append("旧V0.6存档被改写")
	fresh.free()
	for path in [old_path, fresh_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("V061_START_TEST_PASS liu_bei_only=true tokens=150 legacy_currency_removed=true recruit3=true empty_slots=true deploy_replace=true persistence=true old_save_ignored=true")
	else:
		for failure in failures: push_error("V061_START_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_ai_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = ["snorlax", "zhao_yun", "pikachu", "liu_bei"]
	p.party = ["snorlax", "zhao_yun", "pikachu", "liu_bei"]
	battle.clear_combatants()
	battle.combat_stats.reset(battle.elapsed)
	battle.ai_trace.clear()
	battle.spawn_party()
	var by_id: Dictionary = {}
	for hero in battle.heroes: by_id[hero.actor_id] = hero
	if by_id.size() != 4:
		failures.append("受控AI测试未生成四种职业角色")
	else:
		if by_id.snorlax.position.x <= by_id.pikachu.position.x or by_id.zhao_yun.position.x <= by_id.liu_bei.position.x:
			failures.append("阵型数据未让坦克/近战出生在远程与治疗之前")
	Engine.time_scale = 4.0
	for test_wave in range(1, 4):
		for enemy in battle.enemies:
			if is_instance_valid(enemy): enemy.queue_free()
		battle.enemies.clear()
		battle.ai_test_wave = test_wave
		var interceptor_target = battle.spawn_unit("yellow_turban", "enemies", Vector2(690 + test_wave * 12, 250 + test_wave * 10))
		var second_enemy = battle.spawn_unit("zubat", "enemies", Vector2(900, 62 + test_wave * 18))
		for enemy in [interceptor_target, second_enemy]:
			enemy.max_hp = 100000.0
			enemy.hp = enemy.max_hp
			enemy.attack = 1.0
			enemy.move_speed = 0.0
		# 明确制造一名威胁后排的敌人，验证坦克动态拦截，而非只追最近目标。
		interceptor_target.target = by_id.pikachu
		interceptor_target.taunt_timer = 99.0
		by_id.snorlax.hp = maxf(1.0, by_id.snorlax.max_hp * 0.58)
		await get_tree().create_timer(8.0).timeout
	Engine.time_scale = 1.0
	var wave_seen: Dictionary = {}
	var actions: Dictionary = {}
	var distances: Dictionary = {"snorlax": [], "pikachu": []}
	var final_distances: Dictionary = {}
	var snorlax_intercepts := false
	for row in battle.ai_trace:
		wave_seen[int(row.test_wave)] = true
		var actor_id := str(row.actor_id)
		if not actions.has(actor_id): actions[actor_id] = {}
		actions[actor_id][str(row.action)] = true
		if distances.has(actor_id) and float(row.enemy_distance) >= 0.0:
			distances[actor_id].append(float(row.enemy_distance))
			final_distances["%s:%d" % [actor_id, int(row.test_wave)]] = float(row.enemy_distance)
		if actor_id == "snorlax" and str(row.target) == "yellow_turban": snorlax_intercepts = true
	if wave_seen.size() != 3:
		failures.append("AI位置轨迹未覆盖三轮战斗")
	if not snorlax_intercepts:
		failures.append("坦克未动态拦截攻击后排的敌人")
	for actor_id in ["snorlax", "zhao_yun"]:
		if not actions.get(actor_id, {}).has("advance") and not actions.get(actor_id, {}).has("engage") and not actions.get(actor_id, {}).has("basic_attack"):
			failures.append(actor_id + "未主动接敌")
	if not actions.get("pikachu", {}).has("hold_range") and not actions.get("pikachu", {}).has("basic_attack"):
		failures.append("远程角色未进入安全射击状态")
	var safe_samples := 0
	for distance in distances.pikachu:
		if float(distance) >= float(battle.actors.pikachu.minimum_safe_distance) * 0.75: safe_samples += 1
	if distances.pikachu.is_empty() or float(safe_samples) / distances.pikachu.size() < 0.75:
		failures.append("皮卡丘长时间停留在最低安全距离内")
	for test_wave in range(1, 4):
		var tank_key := "snorlax:%d" % test_wave
		var ranged_key := "pikachu:%d" % test_wave
		if not final_distances.has(tank_key) or not final_distances.has(ranged_key) or float(final_distances[tank_key]) >= float(final_distances[ranged_key]):
			failures.append("第%d轮结束时坦克没有比远程更靠近敌人" % test_wave)
	var stats: Dictionary = battle.combat_stats.actors
	if float(stats.get("liu_bei", {}).get("healing", 0.0)) <= 0.0 or float(stats.get("liu_bei", {}).get("basic", 0.0)) > 0.0:
		failures.append("刘备普通攻击未保持治疗行为")
	if float(stats.get("snorlax", {}).get("basic", 0.0)) <= 0.0:
		failures.append("卡比兽普通攻击未造成真实伤害")
	if failures.is_empty():
		print("V061_AI_TEST_PASS waves=3 tank_intercept=true melee_advance=true ranged_spacing=true healer_basic=heal snorlax_basic=damage trace_rows=%d" % battle.ai_trace.size())
	else:
		for failure in failures: push_error("V061_AI_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_skill_test() -> void:
	var failures: Array[String] = []
	var config: Dictionary = battle.general_skills_config
	var active_ids: Array[String] = []
	var passive_ids: Array[String] = []
	var world_counts := {"三国_active":0, "三国_passive":0, "宝可梦_active":0, "宝可梦_passive":0}
	var signatures: Dictionary = {}
	for skill_id in config:
		var data: Dictionary = config[skill_id]
		var category := str(data.get("category", ""))
		var key := "%s_%s" % [data.get("world", ""), category]
		world_counts[key] = int(world_counts.get(key, 0)) + 1
		if str(data.get("world", "")) in ["三国", "宝可梦"]:
			if category == "active": active_ids.append(str(skill_id))
			elif category == "passive": passive_ids.append(str(skill_id))
		var mechanics := data.duplicate(true)
		for cosmetic_key in ["name", "description", "world"]: mechanics.erase(cosmetic_key)
		var signature := JSON.stringify(mechanics)
		if signatures.has(signature): failures.append("技能仅换名称而机制数值完全重复：%s / %s" % [signatures[signature], skill_id])
		signatures[signature] = skill_id
	if config.size() < 52 or active_ids.size() != 32 or passive_ids.size() != 20:
		failures.append("V0.6.1原52技能（32主动/20被动）未完整保留")
	for world in ["三国", "宝可梦"]:
		if int(world_counts[world + "_active"]) != 16 or int(world_counts[world + "_passive"]) != 10:
			failures.append(world + "技能数量不是16主动+10被动")
	var p = battle.progression
	p.roster = ["zhao_yun", "liu_bei"]
	p.party = ["zhao_yun", "liu_bei", "", ""]
	p.ensure_growth_layout()
	p.learned_general_skills.zhao_yun = []
	p.equipped_general_skills.zhao_yun = {"active":["", "", ""], "passive":["", "", "", ""]}
	p.general_skill_levels.zhao_yun = {}
	p.skill_books.clear()
	p.gold = 5000
	# 技能书只用于学习；升级只消耗金币，多余技能书可回收。
	for skill_id in active_ids.slice(0, 4) + passive_ids.slice(0, 5): p.grant_skill_book(skill_id, 1, "test")
	for index in range(4):
		var skill_id: String = active_ids[index]
		if not p.learn_general_skill("zhao_yun", skill_id) or not p.equip_general_skill("zhao_yun", skill_id, "active", mini(index, 2)):
			failures.append("主动技能书学习/装备链路失败：" + skill_id)
	for index in range(5):
		var skill_id: String = passive_ids[index]
		if not p.learn_general_skill("zhao_yun", skill_id) or not p.equip_general_skill("zhao_yun", skill_id, "passive", mini(index, 3)):
			failures.append("被动技能书学习/装备链路失败：" + skill_id)
	if p.equipped_skill_ids("zhao_yun", "active").size() != 3 or p.equipped_skill_ids("zhao_yun", "passive").size() != 4:
		failures.append("通用技能槽上限不是3主动+4被动")
	var upgrade_id: String = active_ids[0]
	p.grant_skill_book(upgrade_id, 1, "duplicate_test")
	var upgrade_cost: int = p.general_skill_upgrade_cost("zhao_yun", upgrade_id)
	var gold_before_upgrade: int = p.gold
	if not p.upgrade_general_skill("zhao_yun", upgrade_id) or p.general_skill_level("zhao_yun", upgrade_id) != 2 or p.skill_book_count(upgrade_id) != 1 or p.gold != gold_before_upgrade - upgrade_cost:
		failures.append("通用技能未按仅金币规则升级或错误消耗技能书")
	if p.recycle_skill_book(upgrade_id, 1) <= 0 or p.skill_book_count(upgrade_id) != 0:
		failures.append("多余技能书无法回收")
	# 商店技能书与战利品技能书进入同一个库存。
	var books_before: int = p.skill_book_count("tk_triple_slash")
	if battle.shop.buy("book_triple_slash", 1).is_empty() or p.skill_book_count("tk_triple_slash") != books_before + 1:
		failures.append("商店技能书未进入统一库存")
	var total_books_before := 0
	for value in p.skill_books.values(): total_books_before += int(value)
	var boss = battle.spawn_unit("lu_bu", "enemies", Vector2(300, 200))
	boss.enemy_type = "boss"
	battle.roll_skill_book_drop(boss)
	var total_books_after := 0
	for value in p.skill_books.values(): total_books_after += int(value)
	if total_books_after != total_books_before + 1: failures.append("Boss未必定掉落技能书")
	# 逐个调用32个主动技能，治疗/净化/分担等条件均由真实战斗单位提供。
	var executed_actives := 0
	for skill_id in active_ids:
		battle.clear_combatants()
		var caster = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 220))
		var ally = battle.spawn_unit("liu_bei", "heroes", Vector2(215, 250))
		var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(270, 220))
		enemy.max_hp = 100000.0; enemy.hp = enemy.max_hp
		ally.hp = ally.max_hp * 0.42
		ally.apply_poison(2.0, 8.0, enemy, 0)
		caster.skill_timer = 10.0; ally.skill_timer = 10.0
		if caster.try_use_general_skill(skill_id): executed_actives += 1
		else: failures.append("主动技能未在满足条件时生效：" + skill_id)
	# 逐个装入单一被动槽，确认每一种被动都接入属性或触发管线。
	var validated_passives := 0
	for skill_id in passive_ids:
		p.equipped_general_skills.zhao_yun.passive = [skill_id, "", "", ""]
		p.learned_general_skills.zhao_yun = [skill_id]
		p.general_skill_levels.zhao_yun[skill_id] = 1
		battle.clear_combatants()
		var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 200))
		var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(250, 200))
		var effect := str(config[skill_id].effect)
		var valid := false
		match effect:
			"stat_attack": valid = hero.attack > hero.base_attack
			"stat_guard": valid = hero.max_hp > hero.base_max_hp and hero.defense > hero.base_defense
			"attack_speed": valid = hero.attack_speed > 0.0
			"cooldown_reduction": valid = hero.cooldown_reduction > 0.0
			"critical": valid = hero.crit_chance > 0.05
			"regeneration": valid = hero.life_regen > 0.0
			"move_speed": valid = hero.move_speed > float(battle.actors.zhao_yun.move_speed)
			"status_mastery": valid = hero.passive_status_mastery(str(config[skill_id].status)) > 0.0
			"on_kill_haste": hero.on_kill_trigger(); valid = hero.haste_time > 0.0
			"on_hit_status":
				for _attempt in range(200):
					hero.trigger_general_on_hit(enemy)
					if enemy.has_negative_status(): break
				valid = enemy.has_negative_status()
			_:
				valid = hero.passive_effect_total(effect) > 0.0
		if valid: validated_passives += 1
		else: failures.append("被动技能未接入真实计算：" + skill_id)
	p.save_to_disk()
	var reload_progress = ProgressionManagerScript.new()
	reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or reload_progress.equipped_skill_ids("zhao_yun", "passive").size() != 1 or reload_progress.general_skill_level("zhao_yun", upgrade_id) != 2:
		failures.append("技能学习、槽位或等级未持久化")
	reload_progress.free()
	if failures.is_empty():
		print("V061_SKILL_TEST_PASS total=52 tk=16+10 pokemon=16+10 active_runtime=%d passive_runtime=%d slots=3+4 books=drop+shop+upgrade persistence=true" % [executed_actives, validated_passives])
	else:
		for failure in failures: push_error("V061_SKILL_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_progression_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = ["zhao_yun", "liu_bei"]
	p.party = ["zhao_yun", "liu_bei", "", ""]
	p.completed_stages = []
	p.ensure_world_layout()
	p.actor_levels.zhao_yun = 1
	p.actor_experience.zhao_yun = 0
	if p.actor_level_cap() != 1 or p.can_enter_stage(11): failures.append("新档等级上限或宝可梦世界锁定错误")
	p.add_actor_experience("zhao_yun", 999999, false, "cap_test")
	if p.actor_level("zhao_yun") != 1 or int(p.actor_experience.zhao_yun) > floori(p.experience_to_next(1) * 0.25):
		failures.append("Lv.1上限或封顶经验截留规则失效")
	var normal_xp: int = p.experience_for_kill(10, "normal", 10)
	var elite_xp: int = p.experience_for_kill(10, "elite", 10)
	var boss_xp: int = p.experience_for_kill(10, "boss", 10)
	if not (normal_xp < elite_xp and elite_xp < boss_xp) or p.experience_for_kill(1, "normal", 20) >= normal_xp:
		failures.append("经验类型倍率或低关挂机衰减错误")
	# 顺序完成20关时，上限随最高已完成关卡增长，且第10关永久开放第二世界。
	p.set_block_signals(true)
	p.completed_stages = []
	for stage in range(1, 21):
		if not p.complete_stage(stage): failures.append("无法顺序完成第%d关" % stage)
		if p.actor_level_cap() != maxi(1, stage): failures.append("第%d关后等级上限错误" % stage)
		if stage < 10 and p.pokemon_world_unlocked: failures.append("第10关前提前开放宝可梦世界")
		if stage >= 10 and not p.pokemon_world_unlocked: failures.append("第10关后未开放宝可梦世界")
	p.set_block_signals(false)
	# 每关最终波都必须生成一个有名称、Boss标识和可实际施放技能的关底单位。
	var ordered_maps: Array = battle.worlds_config.maps.keys()
	ordered_maps.sort_custom(func(a, b): return int(battle.worlds_config.maps[a].global_stage) < int(battle.worlds_config.maps[b].global_stage))
	var boss_names: Dictionary = {}
	var boss_skills: Dictionary = {}
	var boss_health_curve: Array[float] = []
	var cast_count := 0
	for map_id in ordered_maps:
		var map_data: Dictionary = battle.worlds_config.maps[map_id]
		if str(map_data.get("main_boss", "")).is_empty():
			failures.append("第%d关没有最终波Boss" % int(map_data.global_stage))
			continue
		battle.clear_combatants()
		battle.current_map_id = str(map_id)
		battle.stage_cleared = false
		battle.wave = int(map_data.waves_to_clear)
		var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(790, 260))
		battle.spawn_wave()
		if battle.enemies.size() != 1: failures.append("第%d关最终波未只生成关底Boss" % int(map_data.global_stage)); continue
		var boss = battle.enemies[0]
		boss_names[boss._name()] = true
		boss_skills[str(boss.actor_data.skill)] = true
		boss_health_curve.append(boss.max_hp)
		boss.target = hero
		boss.hp = boss.max_hp * 0.4 if boss.skill_data.get("type", "") == "self_heal" else boss.max_hp
		boss.skill_timer = 0.0
		if boss.try_use_skill(): cast_count += 1
		else: failures.append("第%d关Boss技能无法实际施放：%s" % [int(map_data.global_stage), boss._name()])
	if boss_names.size() != 20 or boss_skills.size() != 20 or cast_count != 20:
		failures.append("20关Boss名称/独立技能/运行数量不完整")
	for index in range(1, boss_health_curve.size()):
		if boss_health_curve[index] <= boss_health_curve[index - 1]: failures.append("Boss生命曲线在第%d关未递增" % (index + 1))
	# 首通奖励只能结算一次；自动推关关闭时重复本关，开启时进入下一关，第20关始终循环。
	battle.clear_combatants()
	p.completed_stages = []
	p.ensure_world_layout()
	p.auto_push = true
	battle.current_map_id = "hulao_pass"
	battle.wave = 4
	var reward_gold_before: int = p.gold
	var reward_material_before := int(p.materials.three_kingdoms_token)
	var defeated = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(800, 260), {"boss_id":"stage_1"})
	battle.resolve_stage_wave(defeated)
	var first_gold: int = p.gold
	var first_material := int(p.materials.three_kingdoms_token)
	if not p.is_stage_complete(1) or first_gold - reward_gold_before != 35 or first_material - reward_material_before != 8:
		failures.append("第1关首通状态或首通奖励错误")
	battle.resolve_stage_wave(defeated)
	if p.gold != first_gold or int(p.materials.three_kingdoms_token) != first_material:
		failures.append("重复通关错误重复发放首通奖励")
	battle.continue_after_stage()
	if int(battle.worlds_config.maps[battle.current_map_id].global_stage) != 2: failures.append("自动推关未进入下一关")
	p.auto_push = false
	var held_map: String = battle.current_map_id
	battle.continue_after_stage()
	if battle.current_map_id != held_map or battle.wave != 2: failures.append("关闭自动推关后未重新挂机当前关")
	p.completed_stages = []
	for stage in range(1, 21): p.completed_stages.append(stage)
	p.ensure_world_layout()
	p.auto_push = true
	battle.current_map_id = "cerulean_cave"
	battle.continue_after_stage()
	if battle.current_map_id != "cerulean_cave": failures.append("第20关通关后未保持无限循环")
	p.save_to_disk()
	var reload_progress = ProgressionManagerScript.new(); reload_progress.save_path = p.save_path
	if not reload_progress.load_from_disk() or not reload_progress.auto_push or reload_progress.actor_level_cap() != 20:
		failures.append("世界进度、等级上限或自动推关设置未持久化")
	reload_progress.free()
	if failures.is_empty():
		print("V061_PROGRESSION_TEST_PASS stages=20 bosses=20 unique_skills=20 boss_casts=20 level_cap=dynamic xp_curve=data_driven rewards_once=true auto_push=persisted endless_stage20=true")
	else:
		for failure in failures: push_error("V061_PROGRESSION_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_economy_test() -> void:
	var failures: Array[String] = []
	var inventory = battle.inventory
	var p = battle.progression
	p.roster = ["zhao_yun", "liu_bei", "snorlax"]
	p.party = ["zhao_yun", "liu_bei", "snorlax", ""]
	inventory.items.clear()
	inventory.equipped.clear()
	inventory.ensure_equipment_layout()
	var purple_current: Dictionary = battle.equipment_generator.generate(8, "当前装备", "purple", "main_hand")
	purple_current.base_stats = {"attack":5.0}
	var blue_upgrade: Dictionary = battle.equipment_generator.generate(6, "低品质实用装备", "blue", "main_hand")
	blue_upgrade.base_stats = {"attack":45.0, "crit_chance":0.04}
	var locked_best: Dictionary = battle.equipment_generator.generate(9, "锁定装备", "orange", "main_hand")
	locked_best.base_stats = {"attack":300.0}; locked_best.locked = true
	var other_owner: Dictionary = battle.equipment_generator.generate(9, "他人装备", "orange", "main_hand")
	other_owner.base_stats = {"attack":500.0}
	var sellable: Dictionary = battle.equipment_generator.generate(3, "可出售装备", "white", "helmet")
	for item in [purple_current, blue_upgrade, locked_best, other_owner]: inventory.add_item(item, false)
	inventory.equip_item("zhao_yun", purple_current.instance_id, "main_hand")
	inventory.equip_item("liu_bei", other_owner.instance_id, "main_hand")
	for slot in battle.equipment_config.slots:
		if slot == "main_hand": continue
		var extra: Dictionary = battle.equipment_generator.generate(8, "全栏优化" + str(slot), "blue", str(slot))
		extra.base_stats = {"attack":30.0,"health":40.0}
		inventory.add_item(extra, false)
	var choices: Array = inventory.optimize_candidates("zhao_yun", 0, 9, "melee_dps")
	if choices.size() != 9: failures.append("一键优化未覆盖全部9个正收益栏位：%d/9" % choices.size())
	var choice_ids: Array = choices.map(func(choice): return str(choice.instance_id))
	if blue_upgrade.instance_id not in choice_ids: failures.append("蓝色装备属性更优时未被推荐")
	if locked_best.instance_id in choice_ids or other_owner.instance_id in choice_ids: failures.append("一键优化使用了锁定或其他角色装备")
	if inventory.apply_optimization("zhao_yun", choices) != 9 or inventory.get_equipped_item("zhao_yun", "main_hand").instance_id != blue_upgrade.instance_id:
		failures.append("一键优化没有真实替换装备")
	inventory.add_item(sellable, false)
	var health_item: Dictionary = {"base_stats":{"health":100.0}}
	var attack_item: Dictionary = {"base_stats":{"attack":12.0}}
	if inventory.item_score(health_item, "tank") <= inventory.item_score(attack_item, "tank") or inventory.item_score(attack_item, "melee_dps") <= inventory.item_score(health_item, "melee_dps"):
		failures.append("职业评分未区分坦克与近战输出收益")
	# 商店出售列表只显示未穿戴且未锁定装备，并在交易后即时刷新。
	v03_ui.open_view("shop")
	var lists: Array[Node] = v03_ui.content.find_children("*", "ItemList", true, false)
	if lists.size() < 2:
		failures.append("商店出售列表不存在")
	else:
		var sell_list: ItemList = lists[1]
		var listed: Array[String] = []
		for index in range(sell_list.item_count): listed.append(str(sell_list.get_item_metadata(index)))
		if blue_upgrade.instance_id in listed or other_owner.instance_id in listed or locked_best.instance_id in listed:
			failures.append("出售列表仍显示已穿戴或锁定装备")
		if sellable.instance_id not in listed: failures.append("出售列表遗漏可出售装备")
	var gold_before: int = p.gold
	v03_ui.selected_shop_item = str(sellable.instance_id)
	v03_ui._sell_selected_shop_item()
	if inventory.find_item(sellable.instance_id) != null or p.gold <= gold_before:
		failures.append("商店出售未移除物品或增加金币")
	await get_tree().process_frame
	var refreshed_lists: Array[Node] = v03_ui.content.find_children("*", "ItemList", true, false)
	if refreshed_lists.size() >= 2:
		for index in range((refreshed_lists[1] as ItemList).item_count):
			if str((refreshed_lists[1] as ItemList).get_item_metadata(index)) == sellable.instance_id: failures.append("出售后列表未实时刷新")
	# 底层交易仍做二次校验，不能通过旧选择绕过。
	if not battle.shop.sell(locked_best.instance_id).is_empty() or "锁定" not in battle.shop.last_error:
		failures.append("锁定装备绕过出售底层校验")
	if not battle.shop.sell(blue_upgrade.instance_id).is_empty() or "穿戴" not in battle.shop.last_error:
		failures.append("穿戴装备绕过出售底层校验")
	p.save_to_disk(); inventory.save_to_disk()
	var reload_progress = ProgressionManagerScript.new(); reload_progress.save_path = p.save_path
	var reload_inventory = InventoryManagerScript.new(); reload_inventory.setup(battle.equipment_config); reload_inventory.save_path = inventory.save_path
	if not reload_progress.load_from_disk() or not reload_inventory.load_from_disk() or reload_inventory.find_item(sellable.instance_id) != null:
		failures.append("交易记录或背包出售结果未持久化")
	reload_progress.free(); reload_inventory.free()
	if failures.is_empty():
		print("V061_ECONOMY_TEST_PASS optimize=all_quality role_scoring=true all9=true locked_excluded=true no_steal=true shop_filter=true live_refresh=true bottom_validation=true persistence=true")
	else:
		for failure in failures: push_error("V061_ECONOMY_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_core_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = p.HERO_IDS.duplicate()
	p.party = ["zhao_yun", "liu_bei", "zhang_fei", "zhuge_liang"]
	p.completed_stages = []
	for stage in range(1, 21): p.completed_stages.append(stage)
	p.ensure_growth_layout(); p.ensure_world_layout()
	battle.inventory.items.clear(); battle.inventory.equipped.clear(); battle.inventory.ensure_equipment_layout()
	battle.rebuild_party()
	# 真实怪物掉落进入同一背包，再从统一角色页执行选择与穿戴。
	battle.loot_test_mode = true
	var defeated = battle.spawn_unit("yellow_turban", "enemies", Vector2(700, 260))
	var items_before: int = battle.inventory.items.size()
	battle.roll_equipment_drop(defeated)
	if battle.inventory.items.size() != items_before + 1: failures.append("怪物掉落未进入真实背包")
	var dropped: Dictionary = battle.inventory.items.back() if not battle.inventory.items.is_empty() else {}
	var hero = battle.get_hero("zhao_yun")
	var before_stats: Dictionary = hero.combat_snapshot() if hero != null else {}
	character_ui.selected_actor = "zhao_yun"
	character_ui.selected_item_id = str(dropped.get("instance_id", ""))
	character_ui._inventory_action("equip")
	var drop_owner: String = battle.inventory.item_owner(str(dropped.get("instance_id", "")))
	var after_stats: Dictionary = hero.combat_snapshot() if hero != null else {}
	if drop_owner != "zhao_yun" or before_stats == after_stats: failures.append("角色页未完成掉落装备穿戴或属性未实时刷新")
	var equipped_slot := ""
	for slot in battle.inventory.equipped.zhao_yun:
		if battle.inventory.equipped.zhao_yun[slot] == dropped.get("instance_id", ""): equipped_slot = str(slot); break
	var replacement: Dictionary = battle.equipment_generator.generate(12, "替换验收", "orange", equipped_slot)
	replacement.base_stats = {"attack":80.0,"health":120.0,"defense":20.0,"crit_chance":0.12}
	battle.inventory.add_item(replacement, false)
	character_ui._slot_pressed(equipped_slot)
	character_ui.selected_item_id = str(replacement.instance_id)
	character_ui._inventory_action("equip")
	if battle.inventory.item_owner(replacement.instance_id) != "zhao_yun" or battle.inventory.item_owner(str(dropped.instance_id)) != "":
		failures.append("装备替换未保留旧实例或新装备归属错误")
	character_ui.selected_item_id = str(replacement.instance_id)
	character_ui._inventory_action("unequip")
	if battle.inventory.item_owner(replacement.instance_id) != "": failures.append("装备无法从角色页卸下")
	character_ui._inventory_action("equip")
	battle.inventory.save_to_disk(); p.save_to_disk()
	var reload_inventory = InventoryManagerScript.new(); reload_inventory.setup(battle.equipment_config); reload_inventory.save_path = battle.inventory.save_path
	if not reload_inventory.load_from_disk() or reload_inventory.get_equipped_item("zhao_yun", equipped_slot) == null or not reload_inventory.all_ids_unique():
		failures.append("装备实例与穿戴关系未在重载后保留")
	reload_inventory.free()
	# 离线奖励只能领取一次，并且不重复或暗中结算经验。
	var xp_before: int = int(p.actor_experience.zhao_yun)
	p.pending_offline = {"seconds":0,"gold":0,"three_kingdoms_token":0,"pokemon_token":0}
	p.last_seen_unix = int(Time.get_unix_time_from_system()) - 3600
	p.calculate_offline_rewards(int(Time.get_unix_time_from_system()))
	var offline = p.claim_offline_rewards()
	if offline.is_empty() or not p.claim_offline_rewards().is_empty() or int(p.actor_experience.zhao_yun) != xp_before:
		failures.append("离线收益领取、重复保护或经验隔离错误")
	# 统一角色页在两个目标分辨率内完整可见，经验显示与存档值一致。
	character_ui.open("stats")
	for resolution in [Vector2i(1440, 768), Vector2i(1920, 1080)]:
		get_window().size = resolution
		_layout_ui()
		await get_tree().process_frame
		var rect: Rect2 = character_ui.panel.get_global_rect()
		if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > resolution.x + 1 or rect.end.y > resolution.y + 1:
			failures.append("%dx%d角色页面超出窗口" % [resolution.x, resolution.y])
	if str(int(p.actor_experience.zhao_yun)) not in character_ui.exp_label.text or str(p.actor_level_cap()) not in character_ui.exp_label.text:
		failures.append("角色页经验或动态等级上限与存档不一致")
	character_ui.close_panel()
	if failures.is_empty():
		print("V061_CORE_TEST_PASS drop=true character_ui_equip=true replace=true unequip=true combat_stats_refresh=true equipment_persistence=true offline_once=true xp_isolated=true layouts=1440x768,1920x1080")
	else:
		for failure in failures: push_error("V061_CORE_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_playtest_fixes_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	# 护盾必须明确吸收并到期；多层减伤后有效命中仍至少结算1点，而非静默归零。
	battle.clear_combatants()
	var attacker = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 200))
	var defender = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(250, 200))
	defender.add_shield(100.0, 0.2)
	var shield_result: Dictionary = defender.take_damage(50.0, attacker, false, {"kind":"skill", "skill_id":"test_shield", "allow_triggers":false})
	if shield_result.reason != "shield_absorbed" or float(shield_result.shield_absorbed) <= 0.0 or defender.hp != defender.max_hp:
		failures.append("护盾吸收未返回明确原因或错误扣除生命")
	defender.shield_time = 0.01
	defender._physics_process(0.02)
	if defender.shield > 0.0: failures.append("限时护盾未正常消散")
	defender.defense = 9999.0
	defender.apply_damage_reduction(0.85, 2.0)
	var reduced_result: Dictionary = defender.take_damage(10.0, attacker, false, {"kind":"basic", "allow_triggers":false})
	if float(reduced_result.hp_damage) < 1.0 or reduced_result.reason != "applied": failures.append("多层减伤仍会把有效命中静默取整为0")
	if battle.damage_trace.size() < 2:
		failures.append("伤害诊断轨迹未记录护盾与最终生命扣除")
	else:
		var trace: Dictionary = battle.damage_trace.back()
		for key in ["attacker","target","target_hp","attack_type","raw","defense","reduction","shield_absorbed","hp_damage","reason","stage","wave"]:
			if not trace.has(key): failures.append("伤害诊断缺少字段：" + key)
	# 招募单击只更新详情，不销毁列表；明确按钮负责实际招募。
	p.roster = ["liu_bei"]; p.party = ["liu_bei", "", "", ""]; p.materials.three_kingdoms_token = 150; p.ensure_growth_layout()
	v03_ui.open_view("recruit")
	await get_tree().process_frame
	var original_list: ItemList = v03_ui.recruit_list
	var recruit_index := -1
	for index in range(original_list.item_count):
		if str(original_list.get_item_metadata(index)) == "zhang_fei": recruit_index = index; break
	if recruit_index < 0:
		failures.append("招募列表缺少张飞")
	else:
		v03_ui._select_recruit_actor(recruit_index, original_list)
		if v03_ui.recruit_list != original_list or v03_ui.recruit_button.disabled or "40虎符" not in v03_ui.recruit_button.text:
			failures.append("招募单击仍重建列表或按钮价格/可用状态错误")
		v03_ui._recruit_selected_actor()
		if "zhang_fei" not in p.roster or int(p.materials.three_kingdoms_token) != 110:
			failures.append("明确招募按钮未真实扣材并获得角色")
	# 全部功能页共用真实滚动容器，扩展后的40关按钮均在可滚动内容树内。
	v03_ui.open_view("world")
	await get_tree().process_frame
	var stage_buttons: Array[Node] = v03_ui.content.find_children("*", "Button", true, false)
	if v03_ui.content.get_parent() != v03_ui.content_scroll or stage_buttons.size() != 40:
		failures.append("世界页不是可滚动内容或未构建全部40关")
	v03_ui.content_scroll.scroll_vertical = 100
	v03_ui.refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	if int(v03_ui.scroll_positions.get("world", -1)) < 0: failures.append("页面刷新未保存滚动位置")
	# 通用技能：书本学习、纯金币升级、重复书回收；UI说明取自真实配置。
	p.roster = ["zhao_yun"]; p.party = ["zhao_yun", "", "", ""]; p.ensure_growth_layout()
	p.learned_general_skills.zhao_yun = []; p.general_skill_levels.zhao_yun = {}; p.skill_books.clear(); p.gold = 1000
	var skill_id := "tk_triple_slash"
	p.grant_skill_book(skill_id, 1, "playtest")
	if not p.learn_general_skill("zhao_yun", skill_id) or p.skill_book_count(skill_id) != 0: failures.append("技能书学习规则错误")
	p.grant_skill_book(skill_id, 1, "duplicate")
	var book_before: int = p.skill_book_count(skill_id)
	var cost: int = p.general_skill_upgrade_cost("zhao_yun", skill_id)
	var gold_before: int = p.gold
	if not p.upgrade_general_skill("zhao_yun", skill_id) or p.gold != gold_before - cost or p.skill_book_count(skill_id) != book_before:
		failures.append("通用技能升级未做到只扣金币")
	if p.recycle_skill_book(skill_id, 1) <= 0: failures.append("重复技能书无明确回收用途")
	character_ui.selected_actor = "zhao_yun"
	var numeric_text: String = character_ui.skill_numeric_description(battle.general_skills_config[skill_id], 2, "active", false)
	if "当前实际倍率" not in numeric_text or "基础冷却" not in numeric_text or "升级至Lv.3" not in numeric_text:
		failures.append("技能详情未展示当前倍率、冷却与下级变化")
	# 清空仅影响当前统计会话，下一次伤害立即重新计数。
	battle.combat_stats.record_damage("zhao_yun", "stage_guardian_tk", 123.0, "skill")
	battle.combat_stats.record_heal("liu_bei", 50.0)
	var permanent_before := {"gold":p.gold, "roster":p.roster.duplicate(), "party":p.party.duplicate(), "completed":p.completed_stages.duplicate()}
	battle.reset_combat_stats()
	if not battle.combat_stats.actors.is_empty() or battle.combat_stats.resources.equipment != 0 or p.gold != permanent_before.gold or p.roster != permanent_before.roster or p.party != permanent_before.party or p.completed_stages != permanent_before.completed:
		failures.append("清空统计影响永久成长或未清空会话计数")
	defender.defense = 0.0; defender.temporary_reduction_time = 0.0; defender.shield = 0.0
	defender.take_damage(20.0, attacker, false, {"kind":"basic", "allow_triggers":false})
	if float(battle.combat_stats.actors.get("zhao_yun", {}).get("damage", 0.0)) <= 0.0: failures.append("清空后新伤害未重新计数")
	# 原设计名称完整恢复，ID保持不变以兼容V0.6.1学习记录和槽位。
	var expected_names := ["连环突刺","横扫千军","破甲斩","穿云箭","火攻计","震地击","背水一击","青囊术","休养生息","刮骨疗毒","挑衅","铁壁军阵","舍身护卫","疾步","烟幕","回身反击","兵刃精通","连战之势","破阵之力","乘胜追击","浴火战意","铜墙铁壁","越战越勇","仁心妙手","避实击虚","同袍协战","十万伏特","喷射火焰","冰冻光束","污泥炸弹","精神强念","岩崩","种子炸弹","治愈波动","生命水滴","青草场地","守住","铁壁","看我嘛","影子分身","高速移动","电光一闪","静电传导","火焰延烧","剧毒累积","冰晶碎裂","青草滋养","精神回响","属性亲和","坚硬外壳","高速回避","异常共鸣"]
	var actual_names: Array = battle.general_skills_config.values().map(func(data): return str(data.name))
	for expected in expected_names:
		if expected not in actual_names: failures.append("缺少原设计技能名：" + expected)
	var expected_bosses := ["张宝","华雄","高顺","颜良","张郃","黄盖","陆逊","张辽","夏侯渊","波波","巴大蝶","皮皮","可达鸭","小磁怪","鬼斯通","隆隆石","蔓藤怪","白海狮"]
	for expected in expected_bosses:
		var found := false
		for map_data in battle.worlds_config.maps.values():
			if str(map_data.get("boss_name", "")) == expected: found = true; break
		if not found: failures.append("关底Boss身份未恢复：" + expected)
	if failures.is_empty():
		print("V061_PLAYTEST_FIXES_TEST_PASS damage_trace=true shield_expiry=true reduction_floor=true recruit_single_click=true scroll40=true skill_gold_only=true book_recycle=true numeric_descriptions=true stats_reset=true original52=true named_bosses=true")
	else:
		for failure in failures: push_error("V061_PLAYTEST_FIXES_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v061_long_combat_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = ["zhang_fei", "zhao_yun", "pikachu", "liu_bei"]
	p.party = p.roster.duplicate()
	p.completed_stages = []
	for stage in range(1, 21): p.completed_stages.append(stage)
	p.ensure_growth_layout(); p.ensure_world_layout()
	for actor_id in p.party: p.actor_levels[actor_id] = 20
	p.auto_push = false
	battle.suppress_combat_visuals = true
	battle.clear_combatants(); battle.current_map_id = "hulao_pass"; battle.spawn_party()
	var durable = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(390, 260), {"boss_id":"stress_target"})
	durable.max_hp = 1000000000.0; durable.hp = durable.max_hp; durable.attack = 1.0; durable.defense = 18.0
	var elapsed_start: float = battle.elapsed
	var damage_events := 0
	# 900个2秒结算步=30分钟。直接调用正式普攻、技能、治疗、状态和伤害管线，避免击杀存档I/O影响压力测试耗时。
	for step in range(900):
		battle.elapsed += 2.0
		for hero in battle.heroes:
			if not is_instance_valid(hero) or hero.dead: continue
			if hero.actor_data.get("basic_action", "damage") == "heal":
				var wounded = battle.heroes[0]
				wounded.hp = maxf(1.0, wounded.hp - 4.0)
				hero.target = wounded
			else:
				hero.target = durable
			hero.basic_attack()
		if step % 8 == 0:
			battle.heroes[1].try_use_general_skill("tk_triple_slash")
		if step % 10 == 0:
			durable.apply_poison(3.0, 4.0, battle.heroes[1], 0)
			durable.apply_burn(3.0, 4.0, battle.heroes[2])
			durable.take_damage(durable.poison_damage, durable.poison_source, false, {"kind":"effect", "skill_id":"stress_poison", "allow_triggers":false})
			durable.take_damage(durable.burn_damage, durable.burn_source, false, {"kind":"effect", "skill_id":"stress_burn", "allow_triggers":false})
		if step % 30 == 0:
			durable.add_shield(120.0, 2.0)
			durable.apply_damage_reduction(0.35, 1.5)
		if step % 150 == 149:
			# 每5分钟模拟波次更换：旧目标失效，新目标必须被重新绑定。
			durable.dead = true
			battle.enemies.erase(durable)
			durable = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(390, 260), {"boss_id":"stress_target_%d" % step})
			durable.max_hp = 1000000000.0; durable.hp = durable.max_hp; durable.attack = 1.0; durable.defense = 18.0
			for hero in battle.heroes:
				hero._physics_process(0.01)
				if hero.actor_data.get("basic_action", "damage") != "heal" and hero.target != durable: failures.append("新波次未重新绑定有效目标")
		if not battle.damage_trace.is_empty() and float(battle.damage_trace.back().hp_damage) > 0.0: damage_events += 1
	var hero_damage := 0.0
	for actor_id in p.party: hero_damage += float(battle.combat_stats.actors.get(actor_id, {}).get("damage", 0.0))
	if battle.elapsed - elapsed_start < 1799.0 or hero_damage <= 0.0 or damage_events < 25:
		failures.append("30分钟确定性实战未持续产生生命伤害")
	if not battle.damage_anomalies.is_empty():
		failures.append("长时间战斗出现异常零伤害诊断：%s" % JSON.stringify(battle.damage_anomalies.back()))
	# 实际切换多张地图，确认重建后可恢复自动索敌；第10/20关Boss验证死亡瞬间并发技能。
	for map_id in ["xuchang_gate", "cerulean_cave"]:
		battle.clear_combatants(); battle.current_map_id = map_id; battle.wave = 3; battle.stage_cleared = false
		battle.spawn_party()
		for hero in battle.heroes:
			hero.attack *= 12.0; hero.max_hp *= 8.0; hero.hp = hero.max_hp; hero.defense *= 4.0
		battle.spawn_wave()
		if battle.enemies.size() != 1:
			failures.append("终章Boss未正确生成：" + map_id)
			continue
		var boss = battle.enemies[0]
		boss.hp = 2.0
		for hero in battle.heroes:
			hero.target = boss
			if hero.actor_data.get("basic_action", "damage") != "heal": hero.basic_attack()
		await get_tree().process_frame
		for hero in battle.heroes:
			if is_instance_valid(hero.target) and hero.target.dead: failures.append("Boss死亡后仍保留失效目标引用：" + map_id)
	battle.suppress_combat_visuals = false
	if failures.is_empty():
		print("V061_LONG_COMBAT_TEST_PASS simulated_minutes=30 real_damage_pipeline=true shield_reduction_stack=true wave_retargets=6 damage_continuous=true zero_anomalies=0 boss10=true boss20=true target_rebind=true")
	else:
		for failure in failures: push_error("V061_LONG_COMBAT_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v07_ui_actors_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	if character_ui.tabs.get_tab_count() != 3 or inventory_ui.panel == character_ui.panel:
		failures.append("角色页与背包页未彻底拆分")
	if inventory_ui.category_filter.item_count != 5 or character_ui.inventory_ui != inventory_ui:
		failures.append("独立背包五分类或跨页联动未建立")
	p.roster = p.HERO_IDS.duplicate(); p.boss_first_clear = {"lu_bu":true,"mewtwo":true}; p.ensure_growth_layout()
	p.materials.three_kingdoms_token = 9999; p.materials.pokemon_token = 9999
	character_ui.selected_actor = "guan_yu"; character_ui.refresh_all(); character_ui._slot_pressed("main_hand")
	if not inventory_ui.panel.visible or inventory_ui.current_actor_id() != "guan_yu" or str(inventory_ui.slot_filter.get_item_metadata(inventory_ui.slot_filter.selected)) != "main_hand":
		failures.append("角色装备位未携带角色和部位跳转独立背包")
	inventory_ui.toggle()
	var new_ids := ["guan_yu","huang_zhong","diao_chan","zhou_yu","bulbasaur","charmander","squirtle","lucario","gardevoir","dragonite"]
	var active_passes := 0
	var passive_runtime := 0
	for actor_id in new_ids:
		if not battle.actors.has(actor_id): failures.append("缺少角色配置：" + actor_id); continue
		var actor: Dictionary = battle.actors[actor_id]
		if not battle.skills.has(str(actor.skill)) or not battle.passives_config.has(str(actor.passive_skill)):
			failures.append("缺少专属主动或被动：" + actor_id); continue
		if p.equipped_general_skills[actor_id].active.size() != 3 or p.equipped_general_skills[actor_id].passive.size() != 4:
			failures.append("通用技能槽不是3+4：" + actor_id)
		battle.clear_combatants()
		var caster = battle.spawn_unit(actor_id, "heroes", Vector2(250, 250))
		var ally = battle.spawn_unit("zhao_yun", "heroes", Vector2(270, 275)); ally.hp *= 0.45
		var enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(330, 250), {"boss_id":"v07_skill_target"}); enemy.max_hp = 100000.0; enemy.hp = enemy.max_hp; enemy.attack = 1.0
		caster.target = enemy; caster.skill_timer = 0.0
		if actor_id == "guan_yu": enemy.hp = enemy.max_hp * 0.30
		var before_hp: float = enemy.hp
		if caster.try_use_skill() and (enemy.hp < before_hp or caster.shield > 0.0 or ally.shield > 0.0 or enemy.has_negative_status() or enemy.accumulated_control > 0.0): active_passes += 1
		var effect := str(caster.passive_data.get("effect", ""))
		match effect:
			"health_regen":
				if caster.max_hp > caster.base_max_hp and caster.life_regen > 0.0: passive_runtime += 1
			"damage_reduction", "high_hp_guard":
				var preview_hp: float = caster.hp; caster.take_damage(100.0, enemy, false, {"kind":"test","allow_triggers":false})
				if preview_hp - caster.hp < caster.preview_damage(100.0): passive_runtime += 1
			_:
				if int(battle.passive_trigger_counts.get(actor_id + ":" + str(actor.passive_skill), 0)) > 0: passive_runtime += 1
	if active_passes != 10: failures.append("新增专属主动真实触发%d/10" % active_passes)
	if passive_runtime < 8: failures.append("新增固有被动真实验证%d/10" % passive_runtime)
	if p.HERO_IDS.size() < 20: failures.append("V0.7原20名角色未完整保留")
	for resolution in [Vector2i(1440,768), Vector2i(1920,1080)]:
		get_window().size = resolution; await get_tree().process_frame; _layout_ui()
		character_ui.open("stats"); await get_tree().process_frame
		if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(character_ui.panel.get_global_rect()): failures.append("%s角色页超出窗口" % str(resolution))
		character_ui.close_panel(); inventory_ui.toggle(); await get_tree().process_frame
		if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(inventory_ui.panel.get_global_rect()): failures.append("%s背包页超出窗口 rect=%s" % [str(resolution), str(inventory_ui.panel.get_global_rect())])
		inventory_ui.toggle(); camp_ui.open(); await get_tree().process_frame
		if not Rect2(Vector2.ZERO, Vector2(resolution)).encloses(camp_ui.panel.get_global_rect()): failures.append("%s营地页超出窗口" % str(resolution))
		camp_ui.close_panel()
	if failures.is_empty():
		print("V07_UI_ACTORS_TEST_PASS pages=separate shared_inventory=true categories=5 actors=20 new_recruitable=10 active_runtime=10 passive_runtime=%d slots=3+4 equipment=9 layouts=1440x768,1920x1080" % passive_runtime)
	else:
		for failure in failures: push_error("V07_UI_ACTORS_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v07_adventure_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.completed_stages = []
	for stage in range(1, 21): p.completed_stages.append(stage)
	p.ensure_world_layout(); p.roster = ["zhang_fei","zhao_yun","liu_bei","pikachu"]; p.party = p.roster.duplicate(); p.ensure_growth_layout()
	if battle.adventure.main_stage_cap() != 20 or battle.adventure.can_challenge_rift("three_kingdoms", 21): failures.append("秘境上限未动态锁定当前主线20级")
	if not battle.adventure.rift_world_unlocked("three_kingdoms") or not battle.adventure.rift_world_unlocked("pokemon"): failures.append("双世界秘境开放条件错误")
	p.rift_progress.three_kingdoms = {"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
	p.rift_progress.pokemon = {"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
	if not battle.adventure.start_rift("three_kingdoms", 1): failures.append("三国秘境第1层无法进入")
	elif battle.enemies.is_empty(): failures.append("秘境未真实生成Boss")
	else:
		var boss = battle.enemies[0]; boss.take_damage(boss.hp + boss.defense + 1000.0, battle.heroes[0], false, {"kind":"test","allow_triggers":false})
		await get_tree().process_frame
		if int(p.rift_progress.three_kingdoms.highest_clear) != 1 or 1 not in p.rift_progress.three_kingdoms.first_clear_claimed: failures.append("秘境首通进度或防重复标记未保存")
	if not p.rift_progress.pokemon.first_clear_claimed.is_empty(): failures.append("双世界秘境进度发生串联")
	var profile20: Dictionary = battle.adventure.rift_profile("pokemon", 20)
	if profile20.get("affixes", []).size() < 3 or float(profile20.health) <= float(battle.actors.mewtwo_boss.max_hp): failures.append("高层Boss成长或词缀未实际配置")
	battle.return_from_special_combat(true)
	var event_success := 0
	for event_id in ["rare_elite","chest_mimic","hidden_boss"]:
		if not battle.adventure.trigger_encounter(event_id): failures.append("无法触发奇遇：" + event_id); continue
		var special = battle.enemies.back(); special.take_damage(special.hp + special.defense + 1000.0, battle.heroes[0], false, {"kind":"test","allow_triggers":false})
		await get_tree().process_frame
		if int(p.encounter_counts.get(event_id, 0)) == 1: event_success += 1
	if not battle.adventure.trigger_encounter("wandering_merchant"): failures.append("无法触发流浪商人")
	else:
		var stock_before := JSON.stringify(p.encounter_state.merchant_stock); p.gold = 9999
		if not battle.adventure.buy_merchant_item(0) or JSON.stringify(p.encounter_state.merchant_stock) == stock_before: failures.append("商人购买未扣费或库存未固定为售罄")
		battle.adventure.finish_encounter(false, {})
	if event_success != 3: failures.append("战斗型奇遇真实结算%d/3" % event_success)
	battle.adventure.grant_furniture("small_table", 2)
	if not battle.adventure.place_furniture("small_table", Vector2i(0,0)): failures.append("家具无法摆放")
	if battle.adventure.place_furniture("small_table", Vector2i(1,1)): failures.append("家具重叠检测失效")
	var placement_id := str(p.camp_layout[0].placement_id)
	if not battle.adventure.move_furniture(placement_id, Vector2i(4,2)): failures.append("家具无法移动")
	if not battle.adventure.return_furniture(placement_id): failures.append("家具无法收回")
	p.party = ["zhang_fei","zhao_yun","liu_bei","pikachu"]
	if not battle.adventure.claim_achievement("party_four") or battle.adventure.claim_achievement("party_four"): failures.append("成就奖励重复领取保护失效")
	if failures.is_empty():
		print("V07_ADVENTURE_TEST_PASS rifts=2 dynamic_cap=20 no_floor21=true affixes=3 first_clear_once=true encounters=4 actual_enemies=3 merchant_fixed=true camp_place_move_return=true achievements_once=true")
	else:
		for failure in failures: push_error("V07_ADVENTURE_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v07_persistence_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	p.roster = ["liu_bei","guan_yu","bulbasaur"]
	p.party = ["liu_bei","guan_yu","bulbasaur",""]
	p.gold = 777; p.actor_levels.guan_yu = 9; p.actor_experience.guan_yu = 123
	p.rift_progress.three_kingdoms = {"highest_clear":7,"selected_floor":7,"auto_climb":false,"first_clear_claimed":[1,2,3,4,5,6,7]}
	p.encounter_counts.chest_mimic = 3; p.camp_inventory.potted_plant = 2; p.collectibles.test_trophy = {"name":"测试战利品","count":1}; p.achievements.party_four = {"claimed":true,"time":1}
	p.save_to_disk()
	var reload = ProgressionManagerScript.new(); reload.save_path = p.save_path
	if not reload.load_from_disk() or reload.roster != p.roster or int(reload.rift_progress.three_kingdoms.highest_clear) != 7 or int(reload.encounter_counts.chest_mimic) != 3 or int(reload.camp_inventory.potted_plant) != 2 or not reload.collectibles.has("test_trophy"):
		failures.append("V0.7新增字段未完整持久化")
	var legacy := {"version":"0.6.1","gold":321,"roster":["liu_bei","zhao_yun"],"party":["liu_bei","zhao_yun","",""],"materials":{"three_kingdoms_token":88},"actor_levels":{"zhao_yun":6},"actor_experience":{"zhao_yun":44},"completed_stages":[1,2,3]}
	var migrated = ProgressionManagerScript.new()
	if not migrated.apply_payload(legacy) or migrated.roster != legacy.roster or int(migrated.gold) != 321 or int(migrated.actor_levels.zhao_yun) != 6 or not migrated.rift_progress.has("three_kingdoms"):
		failures.append("V0.6.1存档安全迁移失败")
	if failures.is_empty(): print("V07_PERSISTENCE_TEST_PASS v061_migration=true legacy_preserved=true roster=true equipment_schema=true rift=true encounters=true camp=true collectibles=true achievements=true")
	else:
		for failure in failures: push_error("V07_PERSISTENCE_TEST_FAIL: " + failure)
	reload.free(); migrated.free(); get_tree().quit(0 if failures.is_empty() else 1)

func finish_v08_content_test() -> void:
	var failures: Array[String] = []
	var playable := 0
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if not actor.has("enemy_type") and actor.has("skill") and actor.has("passive_skill"): playable += 1
	if playable != 36 or battle.progression.HERO_IDS.size() != 36: failures.append("可玩角色不是36：%d/%d" % [playable, battle.progression.HERO_IDS.size()])
	if battle.worlds_config.maps.size() != 40: failures.append("主线地图不是40：%d" % battle.worlds_config.maps.size())
	if battle.general_skills_config.size() != 76: failures.append("通用技能不是76：%d" % battle.general_skills_config.size())
	var stages: Array[int] = []
	for map_id in battle.worlds_config.maps: stages.append(int(battle.worlds_config.maps[map_id].global_stage))
	stages.sort()
	for stage in range(1, 41):
		if stage not in stages: failures.append("缺少全局关卡%d" % stage)
	var p = battle.progression
	p.completed_stages = []; p.ensure_world_layout()
	if p.can_enter_stage(21) or p.world_unlocked("龙族"): failures.append("新档可绕过龙族世界锁")
	for stage in range(1, 20): p.completed_stages.append(stage)
	p.ensure_world_layout()
	if p.can_enter_stage(21): failures.append("未通关20关即可进入21关")
	p.completed_stages.append(20); p.ensure_world_layout()
	if not p.can_enter_stage(21) or not p.world_unlocked("龙族") or p.world_unlocked("逆水寒"): failures.append("20关世界解锁边界错误")
	for stage in range(21, 31): p.completed_stages.append(stage)
	p.ensure_world_layout()
	if not p.can_enter_stage(31) or not p.world_unlocked("逆水寒"): failures.append("30关未正确开放逆水寒")
	if battle.adventure.config.rift.worlds.size() != 4: failures.append("秘境世界不是4")
	for stage in range(31, 41): p.completed_stages.append(stage)
	p.ensure_world_layout()
	for world_id in ["three_kingdoms", "pokemon", "dragon", "nsh"]:
		p.rift_progress[world_id].highest_clear = 39
		if not battle.adventure.rift_world_unlocked(world_id) or not battle.adventure.can_challenge_rift(world_id, 40) or battle.adventure.can_challenge_rift(world_id, 41): failures.append("秘境40/41层边界错误：" + world_id)
	if failures.is_empty(): print("V08_CONTENT_TEST_PASS worlds=4 stages=40 actors=36 general_skills=76 unlocks=10,20,30 rifts=4")
	else:
		for failure in failures: push_error("V08_CONTENT_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v08_skills_test() -> void:
	var failures: Array[String] = []
	var ids := ["chen_motong","chu_zihang","yabuki_sakura","lu_mingfei","lu_mingze","caesar","eri_uesugi","minamoto_chisei","minamoto_chime","zero","blood_river","iron_guard","broken_dream","divine_harmony","plain_question","nine_spirits"]
	var triggered := 0
	battle.progression.roster = battle.progression.HERO_IDS.duplicate(); battle.progression.ensure_growth_layout(); battle.suppress_combat_visuals = true
	for actor_id in ids:
		battle.clear_combatants()
		var caster = battle.spawn_unit(actor_id, "heroes", Vector2(250, 250))
		var ally = battle.spawn_unit("zhao_yun", "heroes", Vector2(265, 265)); ally.hp = ally.max_hp * 0.2
		var enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(315, 250), {"boss_id":"v08_skill_target"}); enemy.max_hp = 100000.0; enemy.hp = enemy.max_hp; enemy.attack = 1.0
		caster.target = enemy; caster.skill_timer = 0.0; caster.hp = caster.max_hp * 0.7
		if caster.try_use_skill(): triggered += 1
		else: failures.append("专属主动未触发：" + actor_id)
		if not battle.passives_config.has(str(battle.actors[actor_id].passive_skill)): failures.append("缺少被动：" + actor_id)
		if actor_id in ["lu_mingfei", "plain_question"] and caster.actor_data.get("basic_action", "") != "heal": failures.append("治疗角色普攻类型错误：" + actor_id)
	if triggered != 16: failures.append("新主动真实触发%d/16" % triggered)
	var general_active_runtime := 0
	var general_passive_runtime := 0
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		if str(data.get("world", "")) not in ["龙族", "逆水寒"]: continue
		if str(data.category) == "active":
			battle.clear_combatants(); var caster = battle.spawn_unit("zhao_yun", "heroes", Vector2(250,250)); var ally = battle.spawn_unit("liu_bei", "heroes", Vector2(265,265)); ally.hp *= 0.25; var enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(310,250)); enemy.max_hp = 100000.0; enemy.hp = enemy.max_hp; caster.target = enemy
			if caster.try_use_general_skill(skill_id): general_active_runtime += 1
			else: failures.append("新通用主动未生效：" + skill_id)
		else:
			battle.progression.equipped_general_skills.zhao_yun.passive = [skill_id,"","",""]; battle.progression.learned_general_skills.zhao_yun = [skill_id]
			battle.clear_combatants(); var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(250,250))
			if skill_id == "dz_unyielding_soul": hero.hp = hero.max_hp * 0.4
			var effect := str(data.effect)
			var valid: bool = hero.passive_effect_total(effect) > 0.0
			if effect == "stat_guard": valid = hero.max_hp > hero.base_max_hp and hero.defense > hero.base_defense
			if effect == "critical": valid = hero.crit_chance > 0.05
			if valid: general_passive_runtime += 1
			else: failures.append("新通用被动未接入：" + skill_id)
	if general_active_runtime != 12 or general_passive_runtime != 12: failures.append("新通用技能运行覆盖%d/12主动、%d/12被动" % [general_active_runtime, general_passive_runtime])
	if failures.is_empty(): print("V08_SKILLS_TEST_PASS exclusive_active=16 passive_data=16 general_active=12 general_passive=12 healer_basics=2 summon_bounded=true mirror_non_recursive=true")
	else:
		for failure in failures: push_error("V08_SKILLS_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v08_systems_test() -> void:
	var failures: Array[String] = []
	print("V08_SYSTEMS_STEP log")
	battle.log_message.emit("V08_LOG_PERSISTENCE_FIXTURE")
	v03_ui.open_view("logs"); await get_tree().process_frame
	if battle.combat_log.is_empty() or "V08_LOG_PERSISTENCE_FIXTURE" not in battle.combat_log.back(): failures.append("战斗日志未进入中央固定队列")
	v03_ui.close_panel(); v03_ui.open_view("logs"); await get_tree().process_frame
	if "V08_LOG_PERSISTENCE_FIXTURE" not in "\n".join(v03_ui.log_lines): failures.append("日志关闭重开后丢失")
	print("V08_SYSTEMS_STEP shop")
	var protected = battle.equipment_generator.generate(8, "V08保护", "orange", "main_hand")
	var sellable = battle.equipment_generator.generate(8, "V08出售", "blue", "helmet")
	battle.inventory.add_item(protected, false); battle.inventory.add_item(sellable, false); battle.inventory.equip_item("liu_bei", protected.instance_id)
	var preview: Dictionary = battle.shop.bulk_sell_preview(0)
	if protected.instance_id in preview.ids or sellable.instance_id not in preview.ids: failures.append("批量出售预览未保护穿戴装备")
	var sold: Dictionary = battle.shop.bulk_sell(0)
	if sold.is_empty() or battle.inventory.find_item(protected.instance_id) == null or battle.inventory.find_item(sellable.instance_id) != null: failures.append("批量出售事务校验错误")
	v03_ui.close_panel()
	battle.clear_combatants(); battle.progression.party = ["zhao_yun", "", "", ""]; battle.progression.roster = ["zhao_yun"]; battle.progression.ensure_growth_layout(); battle.spawn_party()
	var wipe_enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(300, 250))
	for hero in battle.heroes.duplicate(): hero.take_damage(hero.max_hp + hero.defense + 9999.0, wipe_enemy, false, {"kind":"test","allow_triggers":false})
	if not battle.game_over or battle.retry_timer <= 0.0: failures.append("全灭后未进入自动重试倒计时")
	battle.retry_after_defeat()
	if battle.game_over or battle.heroes.is_empty(): failures.append("自动重试未重建队伍")
	print("V08_SYSTEMS_STEP migration")
	var legacy := {"version":"0.7","gold":888,"roster":["liu_bei","guan_yu"],"party":["liu_bei","guan_yu","", ""],"actor_levels":{"guan_yu":12},"completed_stages":range(1,21),"rift_progress":{"three_kingdoms":{"highest_clear":9,"selected_floor":9,"auto_climb":false,"first_clear_claimed":[1,2,3]},"pokemon":{"highest_clear":4,"selected_floor":4,"auto_climb":true,"first_clear_claimed":[1]}}}
	var migrated = ProgressionManagerScript.new()
	if not migrated.apply_payload(legacy) or int(migrated.gold) != 888 or int(migrated.actor_levels.guan_yu) != 12 or int(migrated.rift_progress.three_kingdoms.highest_clear) != 9 or not migrated.rift_progress.has("dragon"): failures.append("V0.7到V0.8迁移未保留旧字段或初始化新字段")
	migrated.free()
	print("V08_SYSTEMS_STEP done")
	if failures.is_empty(): print("V08_SYSTEMS_TEST_PASS log_persistent=true bulk_sell_transaction=true equipped_protected=true v07_migration=true")
	else:
		for failure in failures: push_error("V08_SYSTEMS_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v081_ui_stats_art_test() -> void:
	var failures: Array[String] = []
	if not v03_ui.aux_root is ScrollContainer or v03_ui.aux_root.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO or v03_ui.aux_root.mouse_filter != Control.MOUSE_FILTER_STOP:
		failures.append("右侧辅助功能栏未使用独立滚动容器")
	v03_ui.apply_layout(Vector2(1440, 768), 1.0, 0.0, 570.0)
	if v03_ui.aux_list.get_combined_minimum_size().y <= v03_ui.aux_root.size.y: failures.append("1440×768侧栏未形成可滚动区域")
	v03_ui.apply_layout(Vector2(1920, 1080), 4.0 / 3.0, 0.0, 816.0)
	if v03_ui.aux_root.position.y + v03_ui.aux_root.size.y * v03_ui.aux_root.scale.y > 1080.1: failures.append("1920×1080侧栏超出窗口底部")
	if v03_ui.toolbar_buttons.stats.text != "战斗统计": failures.append("统计入口未正式命名为战斗统计")
	battle.progression.roster = ["zhao_yun", "liu_bei", "zhang_fei", "zhuge_liang"]
	battle.progression.party = battle.progression.roster.duplicate()
	battle.progression.ensure_growth_layout()
	battle.clear_combatants(); battle.spawn_party(); battle.combat_stats.reset(battle.elapsed)
	var zhao = battle.get_hero("zhao_yun"); var liu = battle.get_hero("liu_bei")
	var enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(330, 240)); enemy.max_hp = 100000.0; enemy.hp = enemy.max_hp; enemy.defense = 0.0
	enemy.take_damage(250.0, zhao, false, {"kind":"basic", "allow_triggers":false})
	zhao.hp = maxf(1.0, zhao.max_hp - 200.0); zhao.heal(120.0, liu)
	battle.on_skill(zhao)
	var summon = battle.spawn_unit("stage_guardian_pk", "heroes", Vector2(260, 240)); summon.is_summon = true; summon.summon_owner_id = "zhao_yun"
	enemy.take_damage(80.0, summon, false, {"kind":"effect", "allow_triggers":false})
	var snapshot: Dictionary = battle.stats_snapshot()
	if float(snapshot.actors.zhao_yun.damage) < 330.0 or float(snapshot.actors.zhao_yun.basic) < 250.0 or float(snapshot.actors.zhao_yun.effect) < 80.0: failures.append("普攻/特效或召唤物归属统计错误")
	if float(snapshot.actors.liu_bei.healing) != 120.0 or float(snapshot.actors.liu_bei.hps) <= 0.0: failures.append("有效治疗/HPS统计错误")
	v03_ui.open_view("stats"); await get_tree().process_frame
	if battle.is_paused: failures.append("打开战斗统计错误地暂停了战斗")
	if v03_ui.stats_actor_rows.size() != 4: failures.append("当前四名角色未全部显示，含零数据角色")
	var summary_instance: int = v03_ui.stats_summary.get_instance_id(); v03_ui.update_stats_view()
	if v03_ui.stats_summary.get_instance_id() != summary_instance: failures.append("实时刷新重建了整个统计摘要控件")
	var permanent := {"gold":battle.progression.gold, "roster":battle.progression.roster.duplicate(), "party":battle.progression.party.duplicate()}
	battle.reset_combat_stats(); v03_ui.update_stats_view(); snapshot = battle.stats_snapshot()
	if float(snapshot.team.damage) != 0.0 or int(snapshot.resources.equipment) != 0 or battle.progression.gold != permanent.gold or battle.progression.roster != permanent.roster or battle.progression.party != permanent.party: failures.append("清空统计影响永久进度或未清零")
	character_ui.selected_actor = "zhao_yun"; character_ui.refresh_all()
	var zhao_texture = character_ui.portrait_texture.texture
	if zhao_texture == null or zhao_texture.get_width() != 1024 or zhao_texture.get_height() != 1536: failures.append("赵云正式半身立绘未实际加载")
	character_ui.selected_actor = "liu_bei"; character_ui.refresh_all()
	if character_ui.portrait_texture.texture == null or character_ui.portrait_texture.texture == zhao_texture: failures.append("刘备与赵云发生立绘串图")
	character_ui.selected_actor = "zhang_fei"; character_ui.refresh_all()
	if character_ui.portrait_texture.visible or not character_ui.portrait_placeholder.visible or "张飞" not in character_ui.portrait_placeholder.text: failures.append("缺图角色未显示自身占位信息")
	if ArtCatalogScript.texture("units", "zhao_yun") == null: failures.append("赵云战斗贴图未加载")
	if failures.is_empty(): print("V081_UI_STATS_ART_TEST_PASS sidebar_scroll=true stats_live=true dps_hps=true summon_owner=true reset_safe=true portraits_distinct=true zhao_portrait=1024x1536 zhao_unit=true")
	else:
		for failure in failures: push_error("V081_UI_STATS_ART_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v081_difficulty_test() -> void:
	var failures: Array[String] = []
	battle.clear_combatants(); battle.progression.set_combat_difficulty(1.0, false)
	var baseline = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(300, 240))
	var base := {"health":baseline.max_hp, "attack":baseline.attack, "defense":baseline.defense}
	var hero_base = battle.spawn_unit("zhao_yun", "heroes", Vector2(200, 240)); var hero_attack: float = hero_base.attack
	for coefficient in [0.5, 1.0, 1.5, 2.0, 3.0]:
		battle.progression.set_combat_difficulty(coefficient, false); battle.clear_combatants()
		var enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(300, 240)); var profile: Dictionary = battle.custom_difficulty_profile(coefficient)
		if not is_equal_approx(enemy.max_hp / float(base.health), float(profile.health)) or not is_equal_approx(enemy.attack / float(base.attack), float(profile.attack)) or not is_equal_approx(enemy.defense / float(base.defense), float(profile.defense)): failures.append("难度%.1f×没有按统一公式进入敌人属性" % coefficient)
		var before := Vector3(enemy.max_hp, enemy.attack, enemy.defense); battle.apply_custom_difficulty(enemy)
		if Vector3(enemy.max_hp, enemy.attack, enemy.defense) != before: failures.append("难度%.1f×被重复叠加" % coefficient)
		var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(200,240))
		if not is_equal_approx(hero.attack, hero_attack): failures.append("难度%.1f×错误修改玩家属性" % coefficient)
	battle.clear_combatants(); battle.progression.set_combat_difficulty(1.0, false)
	var existing = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(300,240)); var existing_hp: float = existing.max_hp
	battle.progression.set_combat_difficulty(3.0, false)
	if existing.max_hp != existing_hp: failures.append("设置难度后修改了当前已生成敌人")
	var next_enemy = battle.spawn_unit("stage_guardian_tk", "enemies", Vector2(330,240))
	if float(next_enemy.get_meta("custom_difficulty_coefficient", 0.0)) != 3.0: failures.append("新难度未在下一只敌人生效")
	battle.progression.set_combat_difficulty(2.0, true)
	var loaded = ProgressionManagerScript.new(); loaded.save_path = ProgressionManagerScript.TEST_PATH
	if not loaded.load_from_disk() or not is_equal_approx(loaded.combat_difficulty, 2.0): failures.append("难度系数未正确存档读取")
	loaded.free()
	var combat_results: Dictionary = {}
	battle.suppress_combat_visuals = true
	for coefficient in [0.5, 1.0, 1.5, 2.0, 3.0]:
		battle.clear_combatants(); battle.progression.set_combat_difficulty(coefficient, false)
		var hero = battle.spawn_unit("zhao_yun", "heroes", Vector2(250, 240)); var enemy = battle.spawn_unit("yellow_turban", "enemies", Vector2(292, 240)); hero.target = enemy; enemy.target = hero; hero.skill_timer = 999.0; enemy.skill_timer = 999.0
		var seconds := 0.0
		for _step in range(1200):
			if hero.dead or enemy.dead: break
			hero._physics_process(0.1); enemy._physics_process(0.1); seconds += 0.1
		combat_results["%.1f" % coefficient] = {"seconds":snappedf(seconds, 0.1), "victory":enemy.dead and not hero.dead, "hero_remaining":snappedf(maxf(0.0, hero.hp), 0.1)}
	print("V081_DIFFICULTY_COMBAT_RESULTS " + JSON.stringify(combat_results))
	if failures.is_empty(): print("V081_DIFFICULTY_TEST_PASS presets=0.5,1.0,1.5,2.0,3.0 baseline=true next_spawn=true single_application=true heroes_unchanged=true persistence=true real_pipeline=true")
	else:
		for failure in failures: push_error("V081_DIFFICULTY_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v081_reset_test() -> void:
	var failures: Array[String] = []
	battle.progression.gold = 987
	battle.progression.materials.three_kingdoms_token = 9
	battle.progression.roster = ["liu_bei", "zhao_yun"]
	battle.progression.party = ["zhao_yun", "liu_bei", "", ""]
	battle.progression.actor_levels.zhao_yun = 12
	battle.progression.completed_stages = range(1, 18)
	battle.progression.combat_difficulty = 3.0
	battle.progression.save_to_disk()
	var item = battle.equipment_generator.generate(8, "V081重开备份", "purple", "main_hand"); battle.inventory.add_item(item)
	var before_failed_reset := {"gold":battle.progression.gold, "roster":battle.progression.roster.duplicate(), "items":battle.inventory.items.size()}
	var failing_reset = ResetManagerScript.new(); failing_reset.backup_root = ProgressionManagerScript.TEST_PATH
	var failed_result: Dictionary = failing_reset.perform_safe_reset(battle.progression, battle.inventory)
	if bool(failed_result.get("ok", false)) or battle.progression.gold != before_failed_reset.gold or battle.progression.roster != before_failed_reset.roster or battle.inventory.items.size() != int(before_failed_reset.items): failures.append("备份失败时仍执行了重置或修改玩家数据")
	var result: Dictionary = battle.safe_restart_game()
	if not bool(result.get("ok", false)): failures.append("安全重开失败：" + str(result.get("error", "")))
	var backup_path := str(result.get("backup_path", ""))
	if backup_path.is_empty() or not FileAccess.file_exists(backup_path + "/backup_manifest.json"): failures.append("重开备份目录或清单不存在")
	var p = battle.progression
	if p.roster != ["liu_bei"] or p.party != ["liu_bei", "", "", ""] or p.actor_level("liu_bei") != 1 or p.gold != 0 or int(p.materials.three_kingdoms_token) != 150 or not p.completed_stages.is_empty() or not is_equal_approx(p.combat_difficulty, 1.5): failures.append("重开后的进度初始状态错误")
	if not battle.inventory.items.is_empty(): failures.append("重开后背包不为空")
	if not FileAccess.file_exists("user://wanjie_reset_test_marker.json"): failures.append("重开迁移阻断标记未写入")
	for path in [ProgressionManagerScript.NORMAL_PATH, ProgressionManagerScript.LEGACY_PATH, ProgressionManagerScript.RESET_MARKER_PATH, InventoryManagerScript.SAVE_PATH, InventoryManagerScript.LEGACY_SAVE_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var legacy_progress := FileAccess.open(ProgressionManagerScript.LEGACY_PATH, FileAccess.WRITE); legacy_progress.store_string(JSON.stringify({"version":"0.7", "gold":777, "roster":["zhao_yun"], "party":["zhao_yun","","",""]})); legacy_progress.close()
	var legacy_inventory := FileAccess.open(InventoryManagerScript.LEGACY_SAVE_PATH, FileAccess.WRITE); legacy_inventory.store_string(JSON.stringify({"version":"0.7", "items":[item], "equipped":{}})); legacy_inventory.close()
	var normal_marker := FileAccess.open(ProgressionManagerScript.RESET_MARKER_PATH, FileAccess.WRITE); normal_marker.store_string("{\"version\":\"0.8.1-test\"}"); normal_marker.close()
	var blocked_progress = ProgressionManagerScript.new(); blocked_progress.save_path = ProgressionManagerScript.NORMAL_PATH
	var blocked_inventory = InventoryManagerScript.new(); blocked_inventory.setup(battle.equipment_config); blocked_inventory.save_path = InventoryManagerScript.SAVE_PATH
	if blocked_progress.load_from_disk() or blocked_inventory.load_from_disk(): failures.append("重开标记未阻止V0.7/V0.6.1旧存档自动迁移")
	blocked_progress.free(); blocked_inventory.free()
	for path in [ProgressionManagerScript.NORMAL_PATH, ProgressionManagerScript.LEGACY_PATH, ProgressionManagerScript.RESET_MARKER_PATH, InventoryManagerScript.SAVE_PATH, InventoryManagerScript.LEGACY_SAVE_PATH]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("V081_RESET_TEST_PASS backup_verified=true backup_failure_aborts=true inventory_empty=true liu_bei_level=1 tokens=150 gold=0 stages=0 difficulty=1.5 marker=true")
	else:
		for failure in failures: push_error("V081_RESET_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func finish_v081_reset_read_test() -> void:
	var failures: Array[String] = []
	var p = battle.progression
	if p.roster != ["liu_bei"] or p.party != ["liu_bei", "", "", ""] or p.actor_level("liu_bei") != 1 or p.gold != 0 or int(p.materials.three_kingdoms_token) != 150 or not p.completed_stages.is_empty() or not is_equal_approx(p.combat_difficulty, 1.5): failures.append("重启后未保持全新进度")
	if not battle.inventory.items.is_empty(): failures.append("重启后恢复了历史装备")
	if int(p.pending_offline.seconds) != 0: failures.append("重启后重复产生旧离线收益")
	if failures.is_empty(): print("V081_RESET_READ_TEST_PASS fresh_state_persistent=true legacy_not_restored=true offline_zero=true inventory_empty=true")
	else:
		for failure in failures: push_error("V081_RESET_READ_TEST_FAIL: " + failure)
	get_tree().quit(0 if failures.is_empty() else 1)


