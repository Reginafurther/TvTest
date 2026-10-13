class_name InventoryUI
extends CanvasLayer

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")

var battle
var inventory
var config: Dictionary
var panel: PanelContainer
var item_list: ItemList
var equipment_list: ItemList
var actor_select: OptionButton
var slot_filter: OptionButton
var quality_filter: OptionButton
var detail: RichTextLabel
var comparison: RichTextLabel
var capacity_label: Label
var equip_button: Button
var unequip_button: Button
var status_label: Label
var selected_item_id := ""
var selected_equipment_slot := ""
var actor_ids: Array = []
var actor_names: Array = []
var feature_ui

func setup(owner_battle) -> void:
	battle = owner_battle
	layer = 30
	inventory = battle.inventory
	config = battle.equipment_config
	build_ui()
	inventory.inventory_changed.connect(refresh_all)
	inventory.equipment_changed.connect(_on_equipment_changed)
	battle.loot_obtained.connect(_on_loot_obtained)
	refresh_all()

func build_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(194, 108)
	panel.size = Vector2(1052, 540)
	panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("#17262F")
	panel_style.border_color = Color("#6A8898")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(12)
	panel_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	panel.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = "背包与装备"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#FFF0A8"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	capacity_label = Label.new()
	capacity_label.custom_minimum_size = Vector2(170, 28)
	header.add_child(capacity_label)
	var close := Button.new()
	close.text = "关闭  B"
	close.pressed.connect(toggle)
	header.add_child(close)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	root_box.add_child(columns)
	build_inventory_column(columns)
	build_equipment_column(columns)
	build_detail_column(columns)

func apply_layout(viewport_size: Vector2) -> void:
	var factor: float = minf(viewport_size.x / 1440.0, viewport_size.y / 768.0)
	panel.scale = Vector2.ONE * factor
	panel.position = (viewport_size - panel.size * factor) * 0.5

func build_inventory_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(355, 485)
	parent.add_child(column)
	var heading := Label.new()
	heading.text = "所有装备"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	var filters := HBoxContainer.new()
	column.add_child(filters)
	slot_filter = OptionButton.new()
	slot_filter.custom_minimum_size = Vector2(170, 34)
	slot_filter.add_item("全部部位")
	slot_filter.set_item_metadata(0, "")
	for slot in config.get("slots", {}):
		slot_filter.add_item(config.slots[slot])
		slot_filter.set_item_metadata(slot_filter.item_count - 1, slot)
	slot_filter.item_selected.connect(_on_filter_changed)
	filters.add_child(slot_filter)
	quality_filter = OptionButton.new()
	quality_filter.custom_minimum_size = Vector2(150, 34)
	quality_filter.add_item("全部品质")
	quality_filter.set_item_metadata(0, "")
	var qualities: Array = config.get("qualities", {}).keys()
	qualities.sort_custom(func(a, b): return int(config.qualities[a].rank) < int(config.qualities[b].rank))
	for quality in qualities:
		quality_filter.add_item(config.qualities[quality].name)
		quality_filter.set_item_metadata(quality_filter.item_count - 1, quality)
	quality_filter.item_selected.connect(_on_filter_changed)
	filters.add_child(quality_filter)
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.select_mode = ItemList.SELECT_SINGLE
	item_list.item_selected.connect(_on_inventory_selected)
	item_list.item_activated.connect(_on_inventory_activated)
	item_list.tooltip_text = "单击查看，双击可直接为当前角色穿戴"
	column.add_child(item_list)

func build_equipment_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(245, 485)
	parent.add_child(column)
	var heading := Label.new()
	heading.text = "角色装备（9栏）"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	actor_select = OptionButton.new()
	refresh_actor_choices()
	actor_select.item_selected.connect(_on_actor_changed)
	column.add_child(actor_select)
	equipment_list = ItemList.new()
	equipment_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_list.item_selected.connect(_on_equipment_selected)
	column.add_child(equipment_list)
	unequip_button = Button.new()
	unequip_button.text = "卸下所选栏位"
	unequip_button.disabled = true
	unequip_button.pressed.connect(_on_unequip_pressed)
	column.add_child(unequip_button)

func build_detail_column(parent: HBoxContainer) -> void:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.custom_minimum_size = Vector2(320, 485)
	parent.add_child(column)
	var heading := Label.new()
	heading.text = "装备详情与属性对比"
	heading.add_theme_font_size_override("font_size", 18)
	column.add_child(heading)
	detail = RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(0, 250)
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	comparison = RichTextLabel.new()
	comparison.bbcode_enabled = true
	comparison.custom_minimum_size = Vector2(0, 150)
	column.add_child(comparison)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 34)
	status_label.add_theme_color_override("font_color", Color("#FFD27A"))
	column.add_child(status_label)
	equip_button = Button.new()
	equip_button.text = "为当前角色穿戴（也可双击装备）"
	equip_button.disabled = true
	equip_button.pressed.connect(_on_equip_pressed)
	column.add_child(equip_button)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if not panel.visible and feature_ui != null and feature_ui.panel.visible:
		feature_ui.close_panel()
	panel.visible = not panel.visible
	if panel.visible:
		battle.is_paused = true
		battle.battle_state_changed.emit("背包整理中")
		refresh_all()
		set_status("先选择角色，再单击装备查看属性；双击装备可直接穿戴。")
	else:
		battle.is_paused = false
		battle.battle_state_changed.emit("自动战斗中")

func refresh_all() -> void:
	refresh_actor_choices()
	refresh_inventory()
	refresh_equipment()
	capacity_label.text = "容量  %d / %d" % [inventory.items.size(), inventory.capacity]
	var selected = inventory.find_item(selected_item_id)
	equip_button.disabled = selected == null or actor_select.item_count <= 0

func refresh_inventory() -> void:
	item_list.clear()
	var slot_value: String = slot_filter.get_item_metadata(slot_filter.selected) if slot_filter != null else ""
	var quality_value: String = quality_filter.get_item_metadata(quality_filter.selected) if quality_filter != null else ""
	var visible_items: Array = []
	for item in inventory.items:
		if not slot_value.is_empty() and slot_value not in item.get("compatible_slots", [item.get("slot", "")]):
			continue
		if not quality_value.is_empty() and item.get("quality", "") != quality_value:
			continue
		visible_items.append(item)
	visible_items.sort_custom(func(a, b):
		if int(a.quality_rank) == int(b.quality_rank): return int(a.level) > int(b.level)
		return int(a.quality_rank) > int(b.quality_rank))
	for item in visible_items:
		var label := "Lv.%d  %s  [%s]" % [item.level, item.name, slot_name(item.slot)]
		var icon: Texture2D = ArtCatalogScript.texture("equipment_icons", str(item.get("template_id", item.get("slot", ""))))
		var index := item_list.add_item(label, icon)
		item_list.set_item_metadata(index, item.instance_id)
		item_list.set_item_custom_fg_color(index, quality_color(item.quality))
		if item.instance_id == selected_item_id:
			item_list.select(index)

func refresh_equipment() -> void:
	equipment_list.clear()
	var actor_id := current_actor_id()
	for slot in config.get("slots", {}):
		var item = inventory.get_equipped_item(actor_id, slot)
		var label := "%s：%s" % [slot_name(slot), "—" if item == null else item.name]
		var index := equipment_list.add_item(label)
		equipment_list.set_item_metadata(index, slot)
		if item != null:
			equipment_list.set_item_custom_fg_color(index, quality_color(item.quality))
		if slot == selected_equipment_slot:
			equipment_list.select(index)

func show_item(item: Dictionary) -> void:
	if item.is_empty():
		detail.text = "请选择一件装备。"
		comparison.text = ""
		return
	var quality: Dictionary = config.get("qualities", {}).get(item.quality, {})
	var color: String = quality.get("color", "FFFFFF")
	var text := "[font_size=20][color=#%s]%s[/color][/font_size]\n" % [color, item.name]
	text += "等级 %d  ·  %s  ·  %s\n" % [item.level, quality.get("name", ""), slot_name(item.slot)]
	text += "来源：%s\n\n[b]基础属性[/b]\n" % item.get("source", "未知")
	for stat in item.get("base_stats", {}):
		text += "%s  %s\n" % [stat_name(stat), format_value(stat, item.base_stats[stat])]
	text += "\n[b]随机词条[/b]\n"
	if item.get("affixes", []).is_empty():
		text += "无\n"
	for affix in item.get("affixes", []):
		text += "%s  %s\n" % [stat_name(affix.stat), format_value(affix.stat, affix.value)]
	if not item.get("special_effects", []).is_empty():
		text += "\n[b][color=#FFB65B]特殊机制[/color][/b]\n"
		for effect_id in item.special_effects:
			text += "%s\n" % battle.special_config.effects.get(effect_id, {"name": effect_id}).name
	text += "\n[color=#718895]实例ID：%s[/color]" % item.instance_id
	detail.text = text
	show_comparison(item)

func show_comparison(item: Dictionary) -> void:
	var actor_id := current_actor_id()
	var slot := String(item.slot)
	if not selected_equipment_slot.is_empty() and selected_equipment_slot in item.get("compatible_slots", []):
		slot = selected_equipment_slot
	var current = inventory.get_actor_stats(actor_id)
	var preview = inventory.preview_stats(actor_id, item, slot)
	var text := "[b]%s · 穿戴后变化[/b]\n" % actor_names[actor_select.selected]
	var changed := false
	var keys: Array = current.keys()
	for stat in preview:
		if stat not in keys:
			keys.append(stat)
	for stat in keys:
		var delta := float(preview.get(stat, 0)) - float(current.get(stat, 0))
		if absf(delta) > 0.0001:
			changed = true
			var color := "#76E59A" if delta > 0 else "#FF847C"
			text += "[color=%s]%s  %s%s[/color]\n" % [color, stat_name(stat), "+" if delta > 0 else "", format_value(stat, delta)]
	if not changed:
		text += "属性不变"
	comparison.text = text

func _on_inventory_selected(index: int) -> void:
	selected_item_id = item_list.get_item_metadata(index)
	var item = inventory.find_item(selected_item_id)
	if item != null:
		show_item(item)
		equip_button.disabled = false
		var slot := preferred_slot_for_item(item)
		set_status("将为%s穿戴到%s；点击按钮确认，或双击装备。" % [actor_names[actor_select.selected], slot_name(slot)])

func _on_inventory_activated(index: int) -> void:
	_on_inventory_selected(index)
	_on_equip_pressed()

func _on_equipment_selected(index: int) -> void:
	selected_equipment_slot = equipment_list.get_item_metadata(index)
	var item = inventory.get_equipped_item(current_actor_id(), selected_equipment_slot)
	unequip_button.disabled = item == null
	if item != null:
		selected_item_id = item.instance_id
		show_item(item)

func _on_equip_pressed() -> void:
	var item = inventory.find_item(selected_item_id)
	if item == null:
		set_status("请先从左侧选择一件装备。", true)
		return
	var target_slot := preferred_slot_for_item(item)
	if inventory.equip_item(current_actor_id(), selected_item_id, target_slot):
		battle.log_message.emit("%s 装备了 %s" % [actor_names[actor_select.selected], item.name])
		refresh_all()
		show_item(item)
		set_status("穿戴成功：%s → %s的%s，战斗属性已实时刷新。" % [item.name, actor_names[actor_select.selected], slot_name(target_slot)])
	else:
		set_status(inventory.last_error if not inventory.last_error.is_empty() else "穿戴失败，请检查角色和装备部位。", true)

func _on_unequip_pressed() -> void:
	if selected_equipment_slot.is_empty():
		return
	if inventory.unequip_slot(current_actor_id(), selected_equipment_slot):
		battle.log_message.emit("%s 卸下了%s装备" % [actor_names[actor_select.selected], slot_name(selected_equipment_slot)])
		refresh_all()
		unequip_button.disabled = true
		set_status("卸下成功，装备仍保留在背包中。")
	else:
		set_status(inventory.last_error, true)

func _on_actor_changed(_index: int) -> void:
	selected_equipment_slot = ""
	refresh_equipment()
	var item = inventory.find_item(selected_item_id)
	if item != null:
		show_item(item)
		set_status("当前角色：%s；所选装备将穿戴给该角色。" % actor_names[actor_select.selected])

func _on_filter_changed(_index: int) -> void:
	refresh_inventory()

func _on_equipment_changed(_actor_id: String) -> void:
	refresh_all()

func _on_loot_obtained(_item: Dictionary) -> void:
	refresh_inventory()

func current_actor_id() -> String:
	if actor_select == null or actor_select.item_count <= 0 or actor_select.selected < 0:
		return ""
	return actor_select.get_item_metadata(actor_select.selected)

func preferred_slot_for_item(item: Dictionary) -> String:
	var compatible: Array = item.get("compatible_slots", [item.get("slot", "")])
	if not selected_equipment_slot.is_empty() and selected_equipment_slot in compatible:
		return selected_equipment_slot
	var actor_id := current_actor_id()
	for slot in compatible:
		if inventory.get_equipped_item(actor_id, slot) == null:
			return slot
	return String(item.get("slot", compatible[0] if not compatible.is_empty() else ""))

func set_status(message: String, is_error: bool = false) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("#FF8C82") if is_error else Color("#FFD27A"))

func refresh_actor_choices() -> void:
	if actor_select == null or battle == null: return
	var previous := ""
	if actor_select.selected >= 0 and actor_select.selected < actor_select.item_count:
		previous = actor_select.get_item_metadata(actor_select.selected)
	actor_ids = battle.progression.roster.duplicate()
	actor_names.clear()
	actor_select.clear()
	for actor_id in actor_ids:
		var name_value: String = battle.actors.get(actor_id, {}).get("name", actor_id)
		actor_names.append(name_value)
		actor_select.add_item(name_value)
		actor_select.set_item_metadata(actor_select.item_count - 1, actor_id)
		if actor_id == previous: actor_select.select(actor_select.item_count - 1)
	if actor_select.selected < 0 and actor_select.item_count > 0: actor_select.select(0)

func slot_name(slot: String) -> String:
	return config.get("slots", {}).get(slot, slot)

func quality_color(quality: String) -> Color:
	return Color(config.get("qualities", {}).get(quality, {}).get("color", "FFFFFF"))

func stat_name(stat: String) -> String:
	return config.get("affixes", {}).get(stat, {}).get("name", {"health": "生命", "attack": "攻击", "defense": "防御"}.get(stat, stat))

func format_value(stat: String, value: float) -> String:
	var unit: String = config.get("affixes", {}).get(stat, {}).get("unit", "flat")
	if unit == "percent":
		return "%.1f%%" % (value * 100.0)
	return "%.1f" % value
