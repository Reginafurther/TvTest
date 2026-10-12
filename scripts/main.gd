extends Node

var battle: BattleController
var stats_label: Label
var state_label: Label
var log_label: RichTextLabel
var cards: HBoxContainer
var help_label: Label

func _ready() -> void:
	build_background()
	battle = BattleController.new()
	battle.position = Vector2(20, 76)
	add_child(battle)
	build_ui()
	battle.stats_changed.connect(update_stats)
	battle.party_changed.connect(update_party)
	battle.log_message.connect(add_log)
	battle.battle_state_changed.connect(update_state)
	update_party(battle.heroes)
	add_log("四人小队已进入青草渡口，自动战斗开始")

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
	help_label.text = "左键地图：设置集结点    空格：暂停/继续"
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
		label.text = "%s  ·  %s\nHP  %d / %d\n%s  %.1fs" % [unit._name(), unit.actor_data.get("role", ""), unit.hp, unit.max_hp, unit._skill_name(), unit.skill_timer]
		label.add_theme_font_size_override("font_size", 13)
		panel.add_child(label)
		cards.add_child(panel)

func add_log(message: String) -> void:
	if log_label.get_parsed_text().split("\n").size() > 18:
		log_label.clear()
	log_label.append_text("[color=#9CB5C2]›[/color] %s\n" % message)
	log_label.scroll_to_line(999)

