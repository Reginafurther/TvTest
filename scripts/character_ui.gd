class_name CharacterUI
extends CanvasLayer

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const V035ThemeScript = preload("res://scripts/v035_theme.gd")

var battle
var inventory_ui
var panel: PanelContainer
var actor_list: ItemList
var sort_select: OptionButton
var selected_actor := ""
var actor_name: Label
var actor_role: Label
var exp_bar: ProgressBar
var exp_label: Label
var portrait_box: Control
var portrait_texture: TextureRect
var portrait_placeholder: Label
var slot_buttons: Dictionary = {}
var tabs: TabContainer
var stats_text: RichTextLabel
var skills_box: VBoxContainer
var inventory_list: ItemList
var quality_filter: OptionButton
var item_detail: RichTextLabel
var growth_text: RichTextLabel
var feedback: Label
var selected_item_id := ""
var preferred_equipment_slot := ""
var pending_optimization: Array = []
var optimize_dialog: ConfirmationDialog
var party_box: VBoxContainer
var skill_world_filter := "全部"
var skill_category_filter := "全部"

func setup(owner_battle) -> void:
	battle = owner_battle
	layer = 40
	ArtCatalogScript.reload()
	build_ui()
	# Hidden character UI used to rebuild the 76-skill list on every kill/save.
	# That was the primary source of periodic battle hitches in long sessions.
	battle.progression.changed.connect(refresh_if_open)
	battle.inventory.inventory_changed.connect(refresh_if_open)
	battle.inventory.equipment_changed.connect(func(_actor_id): refresh_if_open())
	selected_actor = str(battle.progression.roster[0]) if not battle.progression.roster.is_empty() else ""
	refresh_all()
	panel.visible = false

func refresh_if_open() -> void:
	if panel != null and panel.visible:
		refresh_all()

func build_ui() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#F4E8CC"), Color("#C6924A"), 14, 8))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 22)
	add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	var title := Label.new()
	title.text = "角色养成 · 编队 · 技能 · Build"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	V035ThemeScript.label(title, 24, Color("#3C3027"))
	top.add_child(title)
	feedback = Label.new()
	feedback.custom_minimum_size = Vector2(450, 34)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	V035ThemeScript.label(feedback, 14, Color("#7B5835"))
	top.add_child(feedback)
	var close := Button.new()
	close.text = "返回战斗"
	close.pressed.connect(close_panel)
	V035ThemeScript.button(close, "blue")
	top.add_child(close)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 10)
	outer.add_child(columns)
	build_roster_column(columns)
	build_center_column(columns)
	build_detail_column(columns)
	optimize_dialog = ConfirmationDialog.new()
	optimize_dialog.title = "确认一键优化"
	optimize_dialog.confirmed.connect(_apply_optimization)
	add_child(optimize_dialog)

func build_roster_column(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(235, 0)
	parent.add_child(box)
	var label := Label.new()
	label.text = "已获得角色"
	V035ThemeScript.label(label, 19, Color("#493520"))
	box.add_child(label)
	sort_select = OptionButton.new()
	for value in ["按等级", "按战力", "按定位"]: sort_select.add_item(value)
	sort_select.item_selected.connect(func(_index): refresh_roster())
	box.add_child(sort_select)
	actor_list = ItemList.new()
	actor_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actor_list.custom_minimum_size = Vector2(230, 330)
	actor_list.item_selected.connect(_select_actor)
	box.add_child(actor_list)
	party_box = VBoxContainer.new()
	box.add_child(party_box)
	var hint := Label.new()
	hint.text = "点击仅切换查看，不会改动编队"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	V035ThemeScript.label(hint, 13, Color("#6E553B"))
	box.add_child(hint)

func build_center_column(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(410, 0)
	parent.add_child(box)
	actor_name = Label.new()
	actor_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	V035ThemeScript.label(actor_name, 24, Color("#3C3027"))
	box.add_child(actor_name)
	actor_role = Label.new()
	actor_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	V035ThemeScript.label(actor_role, 15, Color("#765B3C"))
	box.add_child(actor_role)
	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(390, 20)
	exp_bar.show_percentage = false
	box.add_child(exp_bar)
	exp_label = Label.new()
	exp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	V035ThemeScript.label(exp_label, 13, Color("#493520"))
	box.add_child(exp_label)
	portrait_box = Control.new()
	portrait_box.custom_minimum_size = Vector2(400, 450)
	box.add_child(portrait_box)
	portrait_texture = TextureRect.new()
	portrait_texture.name = "CharacterPortrait"
	portrait_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait_texture)
	portrait_placeholder = Label.new()
	portrait_placeholder.name = "CharacterPortraitFallback"
	portrait_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait_placeholder)
	var positions := {
		"main_hand": Vector2(4, 42), "off_hand": Vector2(4, 126), "helmet": Vector2(4, 210),
		"armor": Vector2(288, 42), "gloves": Vector2(288, 126), "boots": Vector2(288, 210),
		"necklace": Vector2(4, 344), "ring_1": Vector2(146, 368), "ring_2": Vector2(288, 344)
	}
	for slot in battle.equipment_config.slots:
		var button := Button.new()
		button.position = positions.get(slot, Vector2.ZERO)
		button.size = Vector2(108, 64)
		button.pressed.connect(_slot_pressed.bind(slot))
		portrait_box.add_child(button)
		slot_buttons[slot] = button
	var optimize := Button.new()
	optimize.text = "一键优化全部9栏（按职业收益）"
	optimize.tooltip_text = "只使用未穿戴装备或当前角色自己的装备，不会拿走其他角色装备"
	optimize.pressed.connect(_preview_optimization)
	V035ThemeScript.button(optimize, "gold")
	box.add_child(optimize)

func build_detail_column(parent: HBoxContainer) -> void:
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.custom_minimum_size = Vector2(610, 620)
	tabs.tab_changed.connect(_refresh_visible_detail_tab)
	parent.add_child(tabs)
	stats_text = RichTextLabel.new()
	stats_text.name = "人物属性"
	stats_text.bbcode_enabled = true
	tabs.add_child(stats_text)
	var skill_scroll := ScrollContainer.new()
	skill_scroll.name = "角色技能"
	skills_box = VBoxContainer.new()
	skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_scroll.add_child(skills_box)
	tabs.add_child(skill_scroll)
	growth_text = RichTextLabel.new()
	growth_text.name = "成长与定位"
	growth_text.bbcode_enabled = true
	tabs.add_child(growth_text)

func open(tab_name: String = "stats") -> void:
	panel.visible = true
	var names := {"stats": 0, "skills": 1, "growth": 2}
	tabs.current_tab = int(names.get(tab_name, 0))
	refresh_all()

func toggle(tab_name: String = "stats") -> void:
	if panel.visible:
		close_panel()
	else:
		open(tab_name)

func close_panel() -> void:
	panel.visible = false

func refresh_all() -> void:
	if battle == null or panel == null:
		return
	if selected_actor.is_empty() or selected_actor not in battle.progression.roster:
		selected_actor = str(battle.progression.roster[0]) if not battle.progression.roster.is_empty() else ""
	refresh_roster()
	refresh_party_controls()
	refresh_center()
	_refresh_visible_detail_tab(tabs.current_tab)

func _refresh_visible_detail_tab(tab_index: int) -> void:
	if battle == null or selected_actor.is_empty(): return
	match tab_index:
		0: refresh_stats()
		1: refresh_skills()
		2: refresh_growth()

func refresh_roster() -> void:
	actor_list.clear()
	var ids: Array = battle.progression.roster.duplicate()
	match sort_select.selected:
		0: ids.sort_custom(func(a, b): return battle.progression.actor_level(a) > battle.progression.actor_level(b))
		1: ids.sort_custom(func(a, b): return actor_power(a) > actor_power(b))
		2: ids.sort_custom(func(a, b): return str(battle.actors[a].role) < str(battle.actors[b].role))
	for actor_id in ids:
		var data: Dictionary = battle.actors.get(actor_id, {})
		var deployed: bool = actor_id in battle.progression.party
		actor_list.add_item("%s  Lv.%d\n%s  %s" % [data.get("name", actor_id), battle.progression.actor_level(actor_id), data.get("role", ""), "●上阵" if deployed else "○待命"])
		actor_list.set_item_metadata(actor_list.item_count - 1, actor_id)
		if actor_id == selected_actor: actor_list.select(actor_list.item_count - 1)

func refresh_party_controls() -> void:
	for child in party_box.get_children(): child.queue_free()
	var heading := Label.new()
	heading.text = "四人上阵位置（允许空位）"
	V035ThemeScript.label(heading, 15, Color("#493520"))
	party_box.add_child(heading)
	for index in range(4):
		var row := HBoxContainer.new()
		var current := str(battle.progression.party[index])
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%d. %s" % [index + 1, battle.actors.get(current, {}).get("name", "空位") if not current.is_empty() else "空位"]
		row.add_child(label)
		var assign := Button.new()
		assign.text = "替换"
		assign.disabled = selected_actor.is_empty()
		assign.pressed.connect(_assign_selected_actor.bind(index))
		row.add_child(assign)
		var clear := Button.new()
		clear.text = "卸下"
		clear.disabled = current.is_empty()
		clear.pressed.connect(_clear_party_slot.bind(index))
		row.add_child(clear)
		party_box.add_child(row)

func refresh_center() -> void:
	if selected_actor.is_empty(): return
	var data: Dictionary = battle.actors.get(selected_actor, {})
	var level: int = battle.progression.actor_level(selected_actor)
	var xp := int(battle.progression.actor_experience.get(selected_actor, 0))
	var needed: int = battle.progression.experience_to_next(level)
	actor_name.text = "%s  Lv.%d" % [data.get("name", selected_actor), level]
	actor_role.text = "%s · %s · %s" % [data.get("world", ""), data.get("role", ""), "上阵中" if selected_actor in battle.progression.party else "未上阵，可正常培养"]
	exp_bar.max_value = needed
	exp_bar.value = xp
	exp_label.text = "Lv.%d / 上限Lv.%d　经验 %d / %d（%.1f%%）" % [level, battle.progression.actor_level_cap(), xp, needed, 100.0 * xp / maxf(1.0, needed)]
	var layout := ArtCatalogScript.layout("portraits", selected_actor)
	var scale := clampf(float(layout.get("scale", 1.0)), 0.25, 2.5)
	var portrait_size := Vector2(170, 270) * scale
	var portrait_position := Vector2(200, 180) - portrait_size * 0.5 + Vector2(float(layout.get("offset_x", 0.0)), float(layout.get("offset_y", 0.0)))
	portrait_texture.position = portrait_position
	portrait_texture.size = portrait_size
	portrait_placeholder.position = portrait_position
	portrait_placeholder.size = portrait_size
	portrait_texture.texture = ArtCatalogScript.portrait(selected_actor)
	portrait_texture.visible = portrait_texture.texture != null
	portrait_placeholder.visible = portrait_texture.texture == null
	portrait_placeholder.text = "%s\n%s\n%s · 立绘待接入" % [str(data.get("name", selected_actor)).substr(0, 1), data.get("name", selected_actor), data.get("role", "未知定位")]
	V035ThemeScript.label(portrait_placeholder, 22, Color(data.get("color", "FFFFFF")))
	for slot in slot_buttons:
		var item = battle.inventory.get_equipped_item(selected_actor, slot)
		var button: Button = slot_buttons[slot]
		button.text = "%s\n%s" % [battle.equipment_config.slots[slot], item.get("name", "空") if item != null else "空"]
		button.tooltip_text = item_summary(item) if item != null else "点击打开背包，选择可穿戴装备"
		var color := Color(battle.equipment_config.qualities.get(item.get("quality", "white"), {}).get("color", "D7DEE3")) if item != null else Color("#C9B894")
		button.add_theme_color_override("font_color", color.darkened(0.35))

func refresh_stats() -> void:
	if selected_actor.is_empty(): return
	var data: Dictionary = battle.actors[selected_actor]
	var level: int = battle.progression.actor_level(selected_actor)
	var base: Dictionary = {"health": float(data.max_hp) * (1.0 + (level - 1) * 0.08), "attack": float(data.attack) * (1.0 + (level - 1) * 0.06), "defense": float(data.defense) * (1.0 + (level - 1) * 0.05), "crit_chance": 0.05, "crit_damage": 1.5, "attack_speed": 0.0, "cooldown_reduction": 0.0, "physical_damage":0.0, "elemental_damage":0.0, "life_regen":0.0}
	var gear: Dictionary = battle.inventory.get_actor_stats(selected_actor)
	var final: Dictionary = base.duplicate(true)
	for key in gear: final[key] = float(final.get(key, 0)) + float(gear[key])
	var live = battle.get_hero(selected_actor)
	if live != null: final = live.combat_snapshot()
	stats_text.text = "[font_size=22][b]%s · 人物属性[/b][/font_size]\n等级 Lv.%d / 当前上限 Lv.%d　当前经验 %d / %d\n\n[b]最终生效属性（基础 / 装备 / 最终）[/b]\n%s\n\n仅展示已接入实际战斗公式的属性；装备变更会即时刷新。" % [data.name, level, battle.progression.actor_level_cap(), int(battle.progression.actor_experience[selected_actor]), battle.progression.experience_to_next(level), stat_rows(base, gear, final)]

func stat_rows(base: Dictionary, gear: Dictionary, final: Dictionary) -> String:
	var labels := {"health":"[基础] 生命", "attack":"[基础] 攻击", "defense":"[基础] 防御", "crit_chance":"[攻击] 暴击率", "crit_damage":"[攻击] 暴击伤害", "attack_speed":"[攻击] 攻击速度", "physical_damage":"[攻击] 物理增伤", "elemental_damage":"[攻击] 元素增伤", "cooldown_reduction":"[特殊] 冷却缩减", "life_regen":"[防御] 生命恢复"}
	var rows: Array[String] = []
	for key in labels:
		var percent: bool = key in ["crit_chance", "crit_damage", "attack_speed", "cooldown_reduction", "physical_damage", "elemental_damage"]
		var scale: float = 100.0 if percent else 1.0
		var suffix: String = "%" if percent else ""
		rows.append("%s　　%.1f%s　　+%.1f%s　　[b]%.1f%s[/b]" % [labels[key], float(base.get(key, 0)) * scale, suffix, float(gear.get(key, 0)) * scale, suffix, float(final.get(key, 0)) * scale, suffix])
	return "\n".join(rows)

func refresh_skills() -> void:
	for child in skills_box.get_children(): child.queue_free()
	if selected_actor.is_empty(): return
	var p = battle.progression
	var actor: Dictionary = battle.actors[selected_actor]
	var filter_row := HBoxContainer.new(); skills_box.add_child(filter_row)
	for world in ["全部", "三国", "宝可梦", "龙族", "逆水寒"]:
		var button := Button.new(); button.text = world; button.disabled = skill_world_filter == world; button.pressed.connect(_set_skill_world_filter.bind(world)); filter_row.add_child(button)
	var category_row := HBoxContainer.new(); skills_box.add_child(category_row)
	for category_name in ["全部", "主动", "被动"]:
		var button := Button.new(); button.text = category_name; button.disabled = skill_category_filter == category_name; button.pressed.connect(_set_skill_category_filter.bind(category_name)); category_row.add_child(button)
	var exclusive_active: Dictionary = battle.skills[actor.skill]
	var exclusive_active_level: int = p.skill_level(selected_actor, "active")
	add_skill_heading("专属主动 · %s Lv.%d" % [exclusive_active.name, exclusive_active_level], skill_numeric_description(exclusive_active, exclusive_active_level, "active", true))
	add_skill_upgrade_button("升级专属主动", "active")
	var exclusive_passive: Dictionary = battle.passives_config[actor.passive_skill]
	var exclusive_passive_level: int = p.skill_level(selected_actor, "passive")
	add_skill_heading("专属被动 · %s Lv.%d" % [exclusive_passive.name, exclusive_passive_level], skill_numeric_description(exclusive_passive, exclusive_passive_level, "passive", true))
	add_skill_upgrade_button("升级专属被动", "passive")
	var equipped: Dictionary = p.equipped_general_skills[selected_actor]
	add_skill_heading("通用技能配置", "3个主动槽按从左到右顺序自动释放；4个被动槽同时生效。\n释放优先级：%s" % " → ".join(p.skill_priorities[selected_actor]))
	for category in ["active", "passive"]:
		var slots: Array = equipped[category]
		var row := HBoxContainer.new()
		var title := Label.new(); title.text = ("主动槽 " if category == "active" else "被动槽 "); row.add_child(title)
		for slot_index in range(slots.size()):
			var slot := Button.new()
			slot.text = "%d. %s" % [slot_index + 1, skill_name(str(slots[slot_index]))]
			slot.tooltip_text = "点击卸下此槽技能" if not str(slots[slot_index]).is_empty() else "空技能槽"
			slot.disabled = str(slots[slot_index]).is_empty()
			slot.pressed.connect(_unequip_general.bind(category, slot_index))
			row.add_child(slot)
		skills_box.add_child(row)
	var priority := Button.new()
	priority.text = "切换专属 / 通用释放优先级"
	priority.pressed.connect(func(): p.toggle_skill_priority(selected_actor); battle.rebuild_party(); refresh_skills())
	skills_box.add_child(priority)
	for skill_id in battle.general_skills_config:
		var skill: Dictionary = battle.general_skills_config[skill_id]
		if skill_world_filter != "全部" and str(skill.get("world", "")) != skill_world_filter: continue
		if skill_category_filter == "主动" and str(skill.category) != "active": continue
		if skill_category_filter == "被动" and str(skill.category) != "passive": continue
		var learned: bool = skill_id in p.learned_general_skills[selected_actor]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var general_level: int = p.general_skill_level(selected_actor, skill_id)
		var function_name := skill_function_name(str(skill.get("function_type", "damage")))
		label.text = "%s【%s】· %s · %s · Lv.%d\n%s" % [skill_function_icon(str(skill.get("function_type", "damage"))), skill.name, str(skill.get("world", "未知")), function_name, general_level, skill_numeric_description(skill, general_level, str(skill.category), false)]
		label.add_theme_color_override("font_color", skill_function_color(str(skill.get("function_type", "damage"))))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var action := Button.new()
		var equipped_now: bool = skill_id in equipped[str(skill.category)]
		action.text = ("已装备" if equipped_now else "装备") if learned else "学习（技能书×1，持有%d）" % p.skill_book_count(skill_id)
		action.disabled = equipped_now
		action.pressed.connect(_general_skill_action.bind(skill_id, str(skill.category), learned))
		row.add_child(action)
		if learned:
			var upgrade := Button.new()
			var max_level: int = p.general_skill_max_level()
			var upgrade_cost: int = p.general_skill_upgrade_cost(selected_actor, skill_id)
			upgrade.text = "已满级" if general_level >= max_level else "升级至Lv.%d｜%d金币（持有%d）" % [general_level + 1, upgrade_cost, p.gold]
			upgrade.disabled = general_level >= max_level or p.gold < upgrade_cost
			upgrade.pressed.connect(_upgrade_general.bind(skill_id))
			row.add_child(upgrade)
			if p.skill_book_count(skill_id) > 0:
				var recycle := Button.new()
				recycle.text = "回收技能书×1"
				recycle.tooltip_text = "技能升级不消耗书；多余技能书可换金币。"
				recycle.pressed.connect(_recycle_general_book.bind(skill_id))
				row.add_child(recycle)
		skills_box.add_child(row)

func _set_skill_world_filter(value: String) -> void:
	skill_world_filter = value
	refresh_skills()

func _set_skill_category_filter(value: String) -> void:
	skill_category_filter = value
	refresh_skills()

func skill_function_name(value: String) -> String:
	return {"damage":"输出", "healing":"治疗", "defense":"防御", "support":"辅助", "control":"控制/减益", "mobility":"位移/闪避"}.get(value, "输出")

func skill_function_icon(value: String) -> String:
	return {"damage":"◆", "healing":"✚", "defense":"⬟", "support":"★", "control":"◈", "mobility":"➤"}.get(value, "◆")

func skill_function_color(value: String) -> Color:
	return Color({"damage":"#B73D36", "healing":"#26834A", "defense":"#346AA3", "support":"#A66718", "control":"#78469B", "mobility":"#1D8190"}.get(value, "#493520"))

func skill_numeric_description(data: Dictionary, level: int, category: String, exclusive: bool) -> String:
	var lines: Array[String] = [str(data.get("description", ""))]
	var max_level: int = 10 if exclusive else battle.progression.general_skill_max_level()
	var current := 0.0
	var next := 0.0
	if category == "passive" and exclusive:
		current = float(data.get("value", 0.0)) + float(data.get("per_level", 0.0)) * (level - 1)
		next = current + float(data.get("per_level", 0.0))
	elif category == "passive":
		current = float(data.get("power", 0.0)) + float(data.get("power_per_level", 0.0)) * (level - 1)
		next = current + float(data.get("power_per_level", 0.0))
	else:
		current = float(data.get("power", 0.0)) * (1.0 + float(data.get("power_per_level", 0.0)) * (level - 1))
		next = float(data.get("power", 0.0)) * (1.0 + float(data.get("power_per_level", 0.0)) * level)
	var effect := str(data.get("effect", data.get("type", "")))
	if effect == "stat_guard":
		var health_now := float(data.get("health", 0.0)) + float(data.get("power_per_level", 0.0)) * (level - 1)
		var defense_now := float(data.get("defense", 0.0)) + float(data.get("power_per_level", 0.0)) * (level - 1)
		lines.append("当前实际效果：生命 +%.1f%%，防御 +%.1f%%" % [health_now * 100.0, defense_now * 100.0])
		if level < max_level: lines.append("升级至Lv.%d：生命/防御各再提高 %.1f%%" % [level + 1, float(data.get("power_per_level", 0.0)) * 100.0])
	elif current > 0.0:
		var unit_name := "最大生命" if effect == "self_heal" else "触发概率" if effect in ["on_hit_status", "counter"] and category == "passive" else "每秒最大生命" if effect == "regeneration" else "攻击/效果"
		lines.append("当前实际倍率：%.1f%% %s" % [current * 100.0, unit_name])
	if data.has("hits"): lines.append("段数：%d" % int(data.hits))
	if data.has("targets"): lines.append("最多目标：%d" % int(data.targets))
	elif effect == "area_damage": lines.append("最多目标：6")
	elif effect == "chain": lines.append("最多目标：3")
	elif effect in ["heal", "hot", "cleanse", "damage", "armor_break", "burn", "poison", "shock", "freeze", "stun", "low_hp_damage"]: lines.append("目标：1")
	if data.has("cooldown"):
		var cooldown := float(data.cooldown)
		if exclusive: cooldown *= 1.0 - float(data.get("cooldown_per_level", 0.0)) * (level - 1)
		lines.append("基础冷却：%.2f秒（装备冷却缩减另行结算）" % cooldown)
	if data.has("duration"): lines.append("持续：%.1f秒" % float(data.duration))
	if data.has("chance"): lines.append("触发概率：%.1f%%" % (float(data.chance) * 100.0))
	if data.has("shock_chance"): lines.append("麻痹概率：%.1f%%" % (float(data.shock_chance) * 100.0))
	if data.has("armor_break"): lines.append("降低防御：%.1f%%" % (float(data.armor_break) * 100.0))
	if data.has("slow"): lines.append("减速：%.1f%%" % (float(data.slow) * 100.0))
	if data.has("dot_power"): lines.append("每秒持续伤害：%.1f%%攻击" % (float(data.dot_power) * 100.0))
	if data.has("regen"): lines.append("基础每秒恢复：%.1f生命" % float(data.regen))
	if effect == "low_hp_damage": lines.append("自身生命≤40%%时，本次伤害额外×1.65")
	if effect != "stat_guard":
		if level < max_level and (next != current): lines.append("升级至Lv.%d：%.1f%% → %.1f%%" % [level + 1, current * 100.0, next * 100.0])
		else: lines.append("已满级" if level >= max_level else "该效果不随等级变化")
	return "\n".join(lines)

func add_skill_heading(heading: String, detail: String = "") -> void:
	var label := Label.new()
	label.text = heading + ("\n" + detail if not detail.is_empty() else "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	V035ThemeScript.label(label, 16, Color("#493520"))
	skills_box.add_child(label)

func add_skill_upgrade_button(text_value: String, kind: String) -> void:
	var cost: Dictionary = battle.progression.skill_upgrade_cost(selected_actor, kind)
	var button := Button.new()
	button.text = "%s（%d金 / %d尘）" % [text_value, int(cost.gold), int(cost.salvage_dust)]
	button.pressed.connect(_upgrade_exclusive.bind(kind))
	skills_box.add_child(button)

func refresh_inventory() -> void:
	inventory_list.clear()
	var minimums := [0, 3, 4, 2]
	var minimum_rank: int = minimums[quality_filter.selected]
	for item in battle.inventory.items:
		if int(item.get("quality_rank", 0)) < minimum_rank: continue
		var owner: String = battle.inventory.item_owner(str(item.instance_id))
		if not owner.is_empty() and owner != selected_actor: continue
		var owner_name: String = ("当前角色·%s" % battle.equipment_config.slots.get(battle.inventory.item_equipped_slot(str(item.instance_id), selected_actor), "已穿戴")) if owner == selected_actor else "未穿戴"
		inventory_list.add_item("%s%s  Lv.%d  [%s]\n%s" % ["🔒" if item.get("locked", false) else "", item.name, int(item.level), battle.equipment_config.qualities[item.quality].name, owner_name])
		inventory_list.set_item_metadata(inventory_list.item_count - 1, item.instance_id)
		if item.instance_id == selected_item_id: inventory_list.select(inventory_list.item_count - 1)
	refresh_item_detail()

func refresh_item_detail() -> void:
	var item = battle.inventory.find_item(selected_item_id)
	if item == null:
		item_detail.text = "选择装备查看与当前角色的真实属性对比。"
		return
	var slots: Array = item.get("compatible_slots", [item.get("slot", "")])
	var target_slot: String = preferred_equipment_slot if preferred_equipment_slot in slots else str(slots[0])
	if preferred_equipment_slot.is_empty() and "ring_1" in slots and battle.inventory.get_equipped_item(selected_actor, "ring_1") != null: target_slot = "ring_2"
	var old = battle.inventory.get_equipped_item(selected_actor, target_slot)
	var gain: float = battle.inventory.item_score(item) - (battle.inventory.item_score(old) if old != null else 0.0)
	item_detail.text = "[b]%s[/b]　%s\n%s\n当前角色目标栏：%s　综合属性变化：[color=%s]%+.1f[/color]" % [item.name, "已锁定" if item.get("locked", false) else "未锁定", item_summary(item), battle.equipment_config.slots.get(target_slot, target_slot), "#3C9B58" if gain >= 0 else "#C84B45", gain]

func refresh_growth() -> void:
	if selected_actor.is_empty(): return
	var data: Dictionary = battle.actors[selected_actor]
	var history: Array = battle.progression.level_history[selected_actor]
	var lines: Array[String] = []
	for entry in history.slice(0, 8): lines.append("Lv.%d · %s" % [int(entry.level), entry.get("source", "战斗")])
	growth_text.text = "[font_size=22][b]%s · 成长与定位[/b][/font_size]\n\n职业定位：%s\n战斗AI：%s\n站位说明：%s\n\n当前培养：角色Lv.%d / 上限Lv.60；专属主动Lv.%d；专属被动Lv.%d\n\n[b]最近升级历程[/b]\n%s" % [data.name, data.role, ai_description(data), position_description(data), battle.progression.actor_level(selected_actor), battle.progression.skill_level(selected_actor, "active"), battle.progression.skill_level(selected_actor, "passive"), "\n".join(lines) if not lines.is_empty() else "尚无升级记录"]

func _select_actor(index: int) -> void:
	selected_actor = str(actor_list.get_item_metadata(index))
	selected_item_id = ""
	preferred_equipment_slot = ""
	feedback.text = "正在查看%s；编队未改变。" % battle.actors[selected_actor].name
	refresh_all()

func _assign_selected_actor(index: int) -> void:
	if battle.progression.set_party_member(index, selected_actor):
		feedback.text = "%s已上阵到位置%d；战场立即重建。" % [battle.actors[selected_actor].name, index + 1]
		battle.rebuild_party()
		refresh_all()

func _clear_party_slot(index: int) -> void:
	if battle.progression.set_party_member(index, ""):
		feedback.text = "位置%d已清空，角色培养数据保持不变。" % (index + 1)
		battle.rebuild_party()
		refresh_all()

func _slot_pressed(slot: String) -> void:
	preferred_equipment_slot = slot
	feedback.text = "%s：已打开独立背包并筛选可穿戴装备。" % battle.equipment_config.slots[slot]
	if inventory_ui != null:
		inventory_ui.open_for_actor_slot(selected_actor, slot)

func _select_item(index: int) -> void:
	selected_item_id = str(inventory_list.get_item_metadata(index))
	refresh_item_detail()

func _inventory_action(action: String) -> void:
	var item = battle.inventory.find_item(selected_item_id)
	if item == null:
		feedback.text = "请先选择一件装备。"
		return
	match action:
		"equip":
			var owner: String = battle.inventory.item_owner(selected_item_id)
			if not owner.is_empty() and owner != selected_actor:
				feedback.text = "该装备正由%s穿戴；请先在其角色页卸下。" % battle.actors[owner].name
				return
			var slots: Array = item.get("compatible_slots", [item.get("slot", "")])
			var slot: String = preferred_equipment_slot if preferred_equipment_slot in slots else str(slots[0])
			if preferred_equipment_slot.is_empty() or preferred_equipment_slot not in slots:
				for candidate in slots:
					if battle.inventory.get_equipped_item(selected_actor, candidate) == null: slot = str(candidate); break
			if battle.inventory.equip_item(selected_actor, selected_item_id, slot):
				feedback.text = "已为%s穿戴%s，战斗属性已刷新。" % [battle.actors[selected_actor].name, item.name]
				preferred_equipment_slot = ""
		"unequip":
			var owner: String = battle.inventory.item_owner(selected_item_id)
			if owner != selected_actor: feedback.text = "这不是当前角色穿戴的装备。"; return
			for slot in battle.inventory.equipped[selected_actor]:
				if battle.inventory.equipped[selected_actor][slot] == selected_item_id:
					battle.inventory.unequip_slot(selected_actor, slot); feedback.text = "装备已卸下并保留在同一背包实例中。"; break
		"lock":
			battle.inventory.set_item_locked(selected_item_id, not bool(item.get("locked", false)))
			feedback.text = "装备已%s。" % ("锁定" if item.get("locked", false) else "解锁")
	refresh_all()

func _preview_optimization() -> void:
	var role := str(battle.actors.get(selected_actor, {}).get("combat_role", ""))
	pending_optimization = battle.inventory.optimize_candidates(selected_actor, 0, 9, role)
	if pending_optimization.is_empty():
		feedback.text = "当前装备已是最优配置。"
		return
	var lines: Array[String] = []
	for choice in pending_optimization: lines.append("%s → %s（评分 %+.1f）" % [choice.name, battle.equipment_config.slots[choice.slot], float(choice.gain)])
	optimize_dialog.dialog_text = "比较全部9个栏位及所有品质，按当前职业计算整体正收益；锁定装备和其他角色装备不会被使用。\n本次全部替换方案：\n\n" + "\n".join(lines)
	optimize_dialog.popup_centered()

func _apply_optimization() -> void:
	var count: int = battle.inventory.apply_optimization(selected_actor, pending_optimization)
	feedback.text = ("一键优化完成：已更换%d件装备。" % count) if count > 0 else (battle.inventory.last_error if not battle.inventory.last_error.is_empty() else "当前装备已是最优配置。")
	pending_optimization.clear()
	refresh_all()

func _upgrade_exclusive(kind: String) -> void:
	if battle.progression.upgrade_skill(selected_actor, kind):
		feedback.text = "专属%s升级成功并已进入战斗计算。" % ("主动" if kind == "active" else "被动")
		battle.rebuild_party()
	else: feedback.text = "升级失败：资源不足或已满级。"
	refresh_all()

func _general_skill_action(skill_id: String, category: String, learned: bool) -> void:
	if learned:
		if battle.progression.equip_general_skill(selected_actor, skill_id, category): feedback.text = "通用技能已装备并进入自动战斗。"
	else:
		if battle.progression.learn_general_skill(selected_actor, skill_id):
			battle.progression.equip_general_skill(selected_actor, skill_id, category)
			feedback.text = "通用技能学习并装备成功。"
		else: feedback.text = "学习失败：需要对应技能书×1。技能书来自怪物、Boss与商店。"
	battle.rebuild_party()
	refresh_all()

func _unequip_general(category: String, slot_index: int) -> void:
	if battle.progression.unequip_general_skill(selected_actor, category, slot_index):
		feedback.text = "已卸下通用技能，学习记录不会丢失。"
		battle.rebuild_party()
	refresh_all()

func _upgrade_general(skill_id: String) -> void:
	var cost: int = battle.progression.general_skill_upgrade_cost(selected_actor, skill_id)
	if battle.progression.upgrade_general_skill(selected_actor, skill_id): feedback.text = "通用技能升级成功，仅扣除%d金币。" % cost
	else: feedback.text = "通用技能升级失败：金币不足或已满级。"
	battle.rebuild_party()
	refresh_all()

func _recycle_general_book(skill_id: String) -> void:
	var earned: int = battle.progression.recycle_skill_book(skill_id, 1)
	feedback.text = "多余技能书已回收，获得%d金币。" % earned if earned > 0 else "没有可回收的技能书。"
	refresh_all()

func actor_power(actor_id: String) -> float:
	var data: Dictionary = battle.actors[actor_id]
	var level: int = battle.progression.actor_level(actor_id)
	return float(data.max_hp) * (1.0 + (level - 1) * 0.08) * 0.1 + float(data.attack) * (1.0 + (level - 1) * 0.06) * 5.0 + float(data.defense) * (1.0 + (level - 1) * 0.05) * 3.0 + battle.inventory.get_actor_stats(actor_id).values().reduce(func(total, value): return total + float(value), 0.0)

func item_summary(item) -> String:
	if item == null: return ""
	var parts: Array[String] = []
	for key in battle.inventory.item_stats(item): parts.append("%s %.2f" % [key, float(battle.inventory.item_stats(item)[key])])
	return " / ".join(parts)

func skill_name(skill_id: String) -> String:
	return battle.general_skills_config.get(skill_id, {}).get("name", "未装备") if not skill_id.is_empty() else "未装备"

func ai_description(data: Dictionary) -> String:
	match data.get("combat_style", "melee"):
		"healer": return "优先治疗生命比例最低的队友；敌人贴近时后撤。"
		"ranged": return "保持安全距离输出；敌人贴近时主动后撤。"
		"tank": return "主动接敌并承担前排伤害。"
	return "主动接近目标并进行近战输出。"

func position_description(data: Dictionary) -> String:
	return "远程后排" if data.get("combat_style", "melee") in ["ranged", "healer"] else "前排承伤" if data.get("combat_style", "melee") == "tank" else "近战前排"
