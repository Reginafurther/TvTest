class_name V03UI
extends CanvasLayer

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const V035ThemeScript = preload("res://scripts/v035_theme.gd")

var battle
var panel: PanelContainer
var content: VBoxContainer
var content_scroll: ScrollContainer
var title: Label
var current_view := ""
var selected_item_id := ""
var selected_affix := 0
var confirm_dialog: ConfirmationDialog
var pending_dismantle := ""
var boss_dialog: ConfirmationDialog
var pending_boss := ""
var toolbar_buttons: Dictionary = {}
var inventory_ui
var character_ui
var toolbar_root: GridContainer
var aux_root: VBoxContainer
var log_lines: Array[String] = []
var recruit_feedback := ""
var refresh_pending := false
var selected_shop_product := ""
var selected_shop_item := ""
var shop_quantity := 1
var shop_feedback := ""
var selected_skill_actor := ""
var skill_feedback := ""
var rewards_feedback := ""
var shop_icon_cache: Dictionary = {}
var selected_party_actor := ""
var scroll_positions: Dictionary = {}
var recruit_list: ItemList
var recruit_detail: Label
var recruit_button: Button
var recruit_list_scroll := 0.0

func setup(owner_battle) -> void:
	battle = owner_battle
	layer = 20
	build_toolbar()
	build_panel()
	battle.progression_changed.connect(refresh_if_open)
	battle.inventory.inventory_changed.connect(refresh_if_open)
	battle.log_message.connect(_remember_log)

func build_toolbar() -> void:
	toolbar_root = GridContainer.new()
	toolbar_root.columns = 4
	toolbar_root.add_theme_constant_override("h_separation", 4)
	toolbar_root.add_theme_constant_override("v_separation", 4)
	add_child(toolbar_root)
	var backpack_space := Control.new()
	backpack_space.custom_minimum_size = Vector2(105, 57)
	toolbar_root.add_child(backpack_space)
	for spec in [["角色", "party"], ["招募", "recruit"], ["世界", "world"], ["Boss", "boss"], ["锻造", "craft"], ["技能", "strategy"], ["暂停", "pause"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(105, 57)
		button.icon = ArtCatalogScript.texture("function_icons", spec[1])
		V035ThemeScript.button(button, "gold" if spec[1] in ["recruit", "boss"] else "cream")
		if spec[1] == "pause":
			button.pressed.connect(_toggle_pause)
		elif spec[1] in ["party", "strategy"]:
			button.pressed.connect(_open_character_view.bind("growth" if spec[1] == "party" else "skills"))
		else:
			button.pressed.connect(open_view.bind(spec[1]))
		toolbar_root.add_child(button)
		toolbar_buttons[spec[1]] = button
	aux_root = VBoxContainer.new()
	aux_root.add_theme_constant_override("separation", 2)
	add_child(aux_root)
	for spec in [["商店", "shop"], ["收益", "rewards"], ["目标", "objectives"], ["日志", "logs"], ["统计", "stats"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(115, 27)
		V035ThemeScript.button(button, "gold" if spec[1] == "shop" else "blue")
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(open_view.bind(spec[1]))
		aux_root.add_child(button)
		toolbar_buttons[spec[1]] = button

func apply_layout(_viewport_size: Vector2, factor: float, offset_x: float, footer_y: float) -> void:
	toolbar_root.position = Vector2(offset_x + 864 * factor, footer_y + 12 * factor)
	toolbar_root.scale = Vector2.ONE * factor
	aux_root.position = Vector2(offset_x + 1305 * factor, footer_y + 12 * factor)
	aux_root.scale = Vector2.ONE * factor
	panel.position = Vector2(offset_x + 890 * factor, 72 * factor)
	panel.scale = Vector2.ONE * factor

func _toggle_pause() -> void:
	battle.is_paused = not battle.is_paused
	battle.battle_state_changed.emit("已暂停" if battle.is_paused else "自动战斗中")

func _remember_log(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 80: log_lines.pop_front()
	if panel.visible and current_view == "logs": refresh()

func build_panel() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(890, 72)
	panel.size = Vector2(534, 526)
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#17262F")
	style.border_color = Color("#7D9BAA")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	var header := HBoxContainer.new()
	root.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	header.add_child(title)
	var close := Button.new()
	close.text = "关闭"
	close.pressed.connect(close_panel)
	header.add_child(close)
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.follow_focus = true
	content_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(content_scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "确认分解高品质装备"
	confirm_dialog.confirmed.connect(confirm_dismantle)
	add_child(confirm_dialog)
	boss_dialog = ConfirmationDialog.new()
	boss_dialog.title = "传奇 Boss 挑战前确认"
	boss_dialog.confirmed.connect(_confirm_boss)
	add_child(boss_dialog)

func open_view(view: String) -> void:
	if character_ui != null and character_ui.panel.visible:
		character_ui.close_panel()
	if inventory_ui != null and inventory_ui.panel.visible:
		inventory_ui.toggle()
	current_view = view
	panel.visible = true
	battle.is_paused = true
	battle.battle_state_changed.emit("功能界面中")
	refresh()

func _open_character_view(tab_name: String) -> void:
	if panel.visible: close_panel()
	if character_ui != null: character_ui.open(tab_name)

func close_panel() -> void:
	panel.visible = false
	battle.is_paused = false
	battle.battle_state_changed.emit("自动战斗中")

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func refresh_if_open() -> void:
	if panel.visible and not refresh_pending:
		refresh_pending = true
		call_deferred("_perform_deferred_refresh")

func _perform_deferred_refresh() -> void:
	refresh_pending = false
	if panel.visible:
		refresh()

func refresh() -> void:
	if content_scroll != null and not current_view.is_empty():
		scroll_positions[current_view] = content_scroll.scroll_vertical
	clear_content()
	match current_view:
		"world": build_world()
		"recruit", "party": build_recruit()
		"boss": build_boss()
		"craft": build_craft()
		"strategy": build_strategy()
		"stats": build_stats()
		"rewards": build_rewards()
		"objectives": build_objectives()
		"logs": build_logs()
		"shop": build_shop()
	call_deferred("_restore_scroll_position", current_view)

func _restore_scroll_position(view: String) -> void:
	if panel.visible and current_view == view and content_scroll != null:
		content_scroll.scroll_vertical = int(scroll_positions.get(view, 0))

func build_rewards() -> void:
	title.text = "挂机收益"
	var snap: Dictionary = battle.stats_snapshot()
	var info := Label.new()
	var pending: Dictionary = battle.progression.pending_offline
	info.text = "本场自动战斗 %.0f 秒\n获得装备：%d 件　招募材料：%d 个　累计金币：%d\n资源收益估算：%.1f / 分钟\n\n离线挂机（最多8小时）：%d分钟\n待领取：金币%d、虎符%d、精灵结晶%d" % [snap.duration, snap.resources.equipment, snap.resources.materials, battle.progression.gold, snap.resources_per_minute, int(pending.get("seconds", 0)) / 60, int(pending.get("gold", 0)), int(pending.get("three_kingdoms_token", 0)), int(pending.get("pokemon_token", 0))]
	info.add_theme_font_size_override("font_size", 20)
	content.add_child(info)
	var claim := Button.new()
	claim.text = "领取离线收益"
	claim.disabled = int(pending.get("seconds", 0)) <= 0
	claim.pressed.connect(_claim_offline_rewards)
	content.add_child(claim)
	var feedback := Label.new()
	feedback.text = rewards_feedback if not rewards_feedback.is_empty() else "离线收益领取后立即清零并存档，不能重复领取。"
	feedback.add_theme_color_override("font_color", Color("#FFD27A"))
	content.add_child(feedback)

func _claim_offline_rewards() -> void:
	var result: Dictionary = battle.progression.claim_offline_rewards()
	if result.is_empty():
		rewards_feedback = "当前没有可领取的离线收益。"
	else:
		rewards_feedback = "领取成功：金币%d、虎符%d、精灵结晶%d。" % [int(result.gold), int(result.three_kingdoms_token), int(result.pokemon_token)]
		battle.log_message.emit(rewards_feedback)
	refresh()

func build_objectives() -> void:
	title.text = "关卡目标"
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "当前地图：%s\n\n挂机击败怪物并自动拾取装备、金币、经验与世界材料。\n在统一角色页换装、查看成长并配置主动/被动技能。\n按全局1—20关推进；通关三国第10关后永久开放宝可梦世界。" % battle.worlds_config.maps[battle.current_map_id].name
	if not battle.progression.guide_finished:
		var step: int = clampi(battle.progression.guide_step, 0, 5)
		info.text = "当前引导：%d/6\n\n%s" % [step + 1, ["用虎符定向招募", "将输出角色上阵", "观察职业自动战斗", "等待装备掉落", "穿戴一件装备", "补齐四人编队"][step]]
	info.add_theme_font_size_override("font_size", 19)
	content.add_child(info)
	var auto_push := CheckButton.new()
	auto_push.text = "通关后自动进入下一关（第20关后持续重复）"
	auto_push.button_pressed = battle.progression.auto_push
	auto_push.toggled.connect(func(enabled: bool): battle.set_auto_push(enabled))
	content.add_child(auto_push)

func build_logs() -> void:
	title.text = "战斗日志"
	var text_view := RichTextLabel.new()
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.text = "\n".join(log_lines)
	content.add_child(text_view)

func build_shop() -> void:
	title.text = "万界行商 · 买入与出售"
	var summary := Label.new()
	summary.text = "金币：%d　背包：%d/%d　%s" % [battle.progression.gold, battle.inventory.items.size(), battle.inventory.capacity, battle.shop_config.get("rules", {}).get("sell_ratio_hint", "")]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var products := ItemList.new()
	products.custom_minimum_size = Vector2(0, 145)
	for product_id in battle.shop_config.get("products", {}):
		var product: Dictionary = battle.shop_config.products[product_id]
		var quality_name := ""
		if product.get("type", "") == "equipment":
			quality_name = " · %s" % battle.equipment_config.qualities.get(product.get("quality", "white"), {}).get("name", "")
		var index := products.add_item("%s%s　%d金币" % [product.get("name", product_id), quality_name, int(product.get("price", 0))], shop_product_icon(product))
		products.set_item_metadata(index, product_id)
		if product_id == selected_shop_product:
			products.select(index)
	products.item_selected.connect(_select_shop_product.bind(products))
	content.add_child(products)
	var buy_row := HBoxContainer.new()
	content.add_child(buy_row)
	var quantity := SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = int(battle.shop_config.get("rules", {}).get("max_quantity", 20))
	quantity.value = shop_quantity
	quantity.value_changed.connect(func(value): shop_quantity = int(value))
	buy_row.add_child(quantity)
	var buy := Button.new()
	buy.text = "购买所选商品"
	buy.disabled = selected_shop_product.is_empty()
	buy.pressed.connect(_buy_shop_product)
	buy_row.add_child(buy)
	if not selected_shop_product.is_empty():
		var selected: Dictionary = battle.shop_config.products.get(selected_shop_product, {})
		var detail := Label.new()
		detail.text = selected.get("description", "")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(detail)
	var separator := HSeparator.new()
	content.add_child(separator)
	var sell_title := Label.new()
	sell_title.text = "出售背包装备（仅显示未穿戴且未锁定装备）"
	content.add_child(sell_title)
	var sell_list := ItemList.new()
	sell_list.custom_minimum_size = Vector2(0, 105)
	var eligible_ids: Array[String] = []
	for item in battle.inventory.items:
		if battle.shop.is_equipped(item.instance_id) or bool(item.get("locked", false)): continue
		eligible_ids.append(str(item.instance_id))
		var index := sell_list.add_item("%s　售价%d" % [item.name, battle.shop.sell_price(item)])
		sell_list.set_item_metadata(index, item.instance_id)
		if item.instance_id == selected_shop_item:
			sell_list.select(index)
	if selected_shop_item not in eligible_ids: selected_shop_item = ""
	sell_list.item_selected.connect(_select_shop_item.bind(sell_list))
	sell_list.item_activated.connect(_sell_shop_item.bind(sell_list))
	content.add_child(sell_list)
	var sell := Button.new()
	sell.text = "出售所选装备"
	sell.disabled = selected_shop_item.is_empty()
	sell.pressed.connect(_sell_selected_shop_item)
	content.add_child(sell)
	var feedback := Label.new()
	feedback.text = shop_feedback if not shop_feedback.is_empty() else "商店仅售过渡装备；高品质装备仍以刷怪和Boss掉落为主。"
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_color_override("font_color", Color("#FFD27A"))
	content.add_child(feedback)
	if not battle.progression.transaction_log.is_empty():
		var history := Label.new()
		var lines: Array[String] = ["最近交易："]
		for index in range(mini(3, battle.progression.transaction_log.size())):
			var record: Dictionary = battle.progression.transaction_log[index]
			lines.append("%s · %s · 金币%+d" % [record.get("action", "交易"), record.get("detail", ""), int(record.get("gold", 0))])
		history.text = "\n".join(lines)
		history.add_theme_font_size_override("font_size", 12)
		content.add_child(history)

func _select_shop_product(index: int, list: ItemList) -> void:
	selected_shop_product = list.get_item_metadata(index)
	shop_feedback = ""
	refresh()

func shop_product_icon(product: Dictionary) -> Texture2D:
	var key: String = product.get("type", "material") + ":" + product.get("quality", "")
	if shop_icon_cache.has(key):
		return shop_icon_cache[key]
	var color := Color("#67B7FF")
	if product.get("type", "") == "equipment":
		color = Color(battle.equipment_config.qualities.get(product.get("quality", "white"), {}).get("color", "D7DEE3"))
	elif product.get("type", "") == "skill_book":
		color = Color("#B889E8")
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	shop_icon_cache[key] = texture
	return texture

func _buy_shop_product() -> void:
	var result: Dictionary = battle.shop.buy(selected_shop_product, shop_quantity)
	if result.is_empty():
		shop_feedback = battle.shop.last_error
	else:
		var product: Dictionary = battle.shop_config.products[selected_shop_product]
		shop_feedback = "购买成功：%s ×%d，已自动存档。" % [product.name, shop_quantity]
		battle.log_message.emit(shop_feedback)
	refresh()

func _select_shop_item(index: int, list: ItemList) -> void:
	selected_shop_item = list.get_item_metadata(index)
	shop_feedback = ""
	refresh()

func _sell_shop_item(index: int, list: ItemList) -> void:
	selected_shop_item = list.get_item_metadata(index)
	_sell_selected_shop_item()

func _sell_selected_shop_item() -> void:
	var result: Dictionary = battle.shop.sell(selected_shop_item)
	if result.is_empty():
		shop_feedback = battle.shop.last_error
	else:
		shop_feedback = "出售成功，获得%d金币，交易已自动存档。" % int(result.gold)
		battle.log_message.emit(shop_feedback)
		selected_shop_item = ""
	refresh()

func build_world() -> void:
	title.text = "20关主线 · 双世界冒险"
	var info := Label.new()
	info.text = "当前：%s　%s" % [battle.worlds_config.maps[battle.current_map_id].name, "宝可梦世界已开放" if battle.progression.pokemon_world_unlocked else "宝可梦世界可预览，通关三国第10关后开放"]
	content.add_child(info)
	for map_id in battle.worlds_config.maps:
		var data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(data.get("global_stage", 1))
		var complete: bool = battle.progression.is_stage_complete(stage)
		var available: bool = battle.progression.can_enter_stage(stage)
		var button := Button.new()
		var state := "已通关" if complete else "可挑战" if available else "世界锁定" if stage >= 11 and not battle.progression.pokemon_world_unlocked else "前置未通关"
		button.text = "%s · 全局第%d关 · %s（难度Lv.%d） · %s" % [data.world, stage, data.name, int(data.get("difficulty_level", stage)), state]
		button.disabled = (map_id == battle.current_map_id and battle.active_boss_id.is_empty() and not battle.stage_cleared) or not available
		button.tooltip_text = "按全局1—20关顺序推进；角色等级上限仍为60级。"
		button.pressed.connect(_enter_stage.bind(map_id))
		content.add_child(button)

func _enter_stage(map_id: String) -> void:
	if battle.switch_map(map_id):
		close_panel()

func build_boss() -> void:
	title.text = "传奇 Boss 挑战"
	var hint := Label.new()
	hint.text = "挑战前查看能力与推荐等级；首胜永久解锁对应角色，之后可重复挑战。"
	content.add_child(hint)
	for boss_id in battle.worlds_config.bosses:
		var data: Dictionary = battle.worlds_config.bosses[boss_id]
		var button := Button.new()
		var available: bool = battle.progression.is_stage_complete(int(data.get("required_stage", 20)))
		button.text = "%s　%s" % [data.name, ("已首胜，可重复挑战" if battle.progression.boss_first_clear[boss_id] else "主线首胜已解锁角色") if available else "通关全局第%d关后开放" % int(data.get("required_stage", 20))]
		button.disabled = not available
		button.pressed.connect(_preview_boss.bind(boss_id))
		content.add_child(button)

func _preview_boss(boss_id: String) -> void:
	pending_boss = boss_id
	var data: Dictionary = battle.worlds_config.bosses[boss_id]
	var actor: Dictionary = battle.actors[data.actor]
	boss_dialog.dialog_text = "%s\n世界：%s　推荐等级：Lv.8\n生命：%d　攻击：%d　防御：%d\n机制：专属技能、控制抗性与重复控制衰减。\n首胜：永久解锁%s；重复挑战：获得材料。\n\n现在开始挑战？" % [data.name, data.world, int(actor.get("max_hp", 0)), int(actor.get("attack", 0)), int(actor.get("defense", 0)), battle.actors[data.unlock_actor].name]
	boss_dialog.popup_centered()

func _confirm_boss() -> void:
	if battle.start_boss(pending_boss): close_panel()

func build_recruit() -> void:
	title.text = "角色招募与四人编队" if current_view == "recruit" else "伙伴与四人编队"
	var p = battle.progression
	var info := Label.new()
	info.text = "虎符：%d　精灵结晶：%d　已招募：%d/10\n新角色统一使用世界材料定向招募。" % [p.materials.three_kingdoms_token, p.materials.pokemon_token, p.roster.size()]
	content.add_child(info)
	recruit_detail = Label.new()
	recruit_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recruit_detail.text = recruit_feedback if not recruit_feedback.is_empty() else "单击角色查看详情，再点击明确的招募按钮；选择不会刷新或跳回顶部。"
	recruit_detail.add_theme_color_override("font_color", Color("#FFD27A"))
	content.add_child(recruit_detail)
	recruit_list = ItemList.new()
	recruit_list.custom_minimum_size = Vector2(0, 185)
	for actor_id in battle.worlds_config.recruitment.costs:
		var cost: Array = battle.worlds_config.recruitment.costs[actor_id]
		var owned: bool = actor_id in p.roster
		var legendary_locked: bool = actor_id in ["lu_bu", "mewtwo"] and not bool(p.boss_first_clear.get("lu_bu" if actor_id == "lu_bu" else "mewtwo", false))
		var state: String = "已招募" if owned else "需先击败对应Boss" if legendary_locked else "%s ×%d" % [material_name(cost[0]), cost[1]]
		var idx := recruit_list.add_item("%s · %s" % [battle.actors[actor_id].name, state])
		recruit_list.set_item_metadata(idx, actor_id)
		if actor_id == selected_party_actor: recruit_list.select(idx)
	recruit_list.item_selected.connect(_select_recruit_actor.bind(recruit_list))
	content.add_child(recruit_list)
	call_deferred("_restore_recruit_list_scroll")
	recruit_button = Button.new()
	recruit_button.text = "请先选择角色"
	recruit_button.disabled = true
	recruit_button.pressed.connect(_recruit_selected_actor)
	content.add_child(recruit_button)
	_update_recruit_selection_ui()
	var hint := Label.new()
	hint.text = "编队最多4人且允许空位。替换后立即重建战场；等级、装备和技能归属不会改变。"
	content.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 1
	content.add_child(grid)
	for i in range(4):
		var row := HBoxContainer.new()
		var current: String = str(p.party[i])
		var slot_label := Label.new()
		slot_label.custom_minimum_size = Vector2(190, 32)
		slot_label.text = "位置%d：%s" % [i + 1, battle.actors.get(current, {}).get("name", "空位") if not current.is_empty() else "空位"]
		row.add_child(slot_label)
		var assign := Button.new()
		assign.text = "将选中角色上阵/替换"
		assign.disabled = selected_party_actor.is_empty() or selected_party_actor not in p.roster
		assign.pressed.connect(assign_selected_party.bind(i))
		row.add_child(assign)
		var clear := Button.new()
		clear.text = "卸下"
		clear.disabled = current.is_empty()
		clear.pressed.connect(clear_party_slot.bind(i))
		row.add_child(clear)
		grid.add_child(row)

func _select_recruit_actor(index: int, list: ItemList) -> void:
	recruit_list_scroll = list.get_v_scroll_bar().value
	selected_party_actor = str(list.get_item_metadata(index))
	recruit_feedback = "已选择%s；查看价格后点击招募，已拥有角色可直接在下方上阵。" % battle.actors[selected_party_actor].name
	_update_recruit_selection_ui()

func _update_recruit_selection_ui() -> void:
	if recruit_button == null or recruit_detail == null or selected_party_actor.is_empty():
		return
	var p = battle.progression
	var actor: Dictionary = battle.actors[selected_party_actor]
	var cost: Array = battle.worlds_config.recruitment.costs[selected_party_actor]
	var owned: bool = selected_party_actor in p.roster
	var legendary_locked: bool = selected_party_actor in ["lu_bu", "mewtwo"] and not bool(p.boss_first_clear.get("lu_bu" if selected_party_actor == "lu_bu" else "mewtwo", false))
	var current_amount: int = int(p.materials.get(str(cost[0]), 0))
	recruit_detail.text = "%s｜%s｜%s\n消耗：%s ×%d　当前持有：%d\n%s" % [actor.name, actor.get("role", "冒险者"), actor.get("world", ""), material_name(str(cost[0])), int(cost[1]), current_amount, recruit_feedback]
	if owned:
		recruit_button.text = "已招募｜请在下方选择上阵位置"
		recruit_button.disabled = true
	elif legendary_locked:
		recruit_button.text = "需先击败对应世界Boss"
		recruit_button.disabled = true
	elif current_amount < int(cost[1]):
		recruit_button.text = "招募：%d%s｜材料不足（当前%d）" % [int(cost[1]), material_name(str(cost[0])), current_amount]
		recruit_button.disabled = true
	else:
		recruit_button.text = "招募：%d%s" % [int(cost[1]), material_name(str(cost[0]))]
		recruit_button.disabled = false

func _recruit_selected_actor() -> void:
	if selected_party_actor.is_empty(): return
	recruit_list_scroll = recruit_list.get_v_scroll_bar().value if recruit_list != null else recruit_list_scroll
	var cost: Array = battle.worlds_config.recruitment.costs[selected_party_actor]
	if battle.progression.exchange_actor(selected_party_actor, str(cost[0]), int(cost[1])):
		recruit_feedback = "材料招募成功：%s。请选择下方位置上阵。" % battle.actors[selected_party_actor].name
		battle.log_message.emit("定向招募：%s" % battle.actors[selected_party_actor].name)
	else:
		recruit_feedback = "%s不足，无法定向招募%s。" % [material_name(str(cost[0])), battle.actors[selected_party_actor].name]
	refresh()

func _restore_recruit_list_scroll() -> void:
	if recruit_list != null and is_instance_valid(recruit_list):
		recruit_list.get_v_scroll_bar().value = recruit_list_scroll

func build_craft() -> void:
	title.text = "装备分解与词条重铸"
	var info := Label.new()
	info.text = "重铸材料：%d　穿戴中的装备不可分解；双击装备选择" % battle.progression.materials.salvage_dust
	content.add_child(info)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 235)
	for item in battle.inventory.items:
		var special := " ★专属" if not item.get("special_effects", []).is_empty() else ""
		var idx := list.add_item("Lv.%d %s%s" % [item.level, item.name, special])
		list.set_item_metadata(idx, item.instance_id)
	list.item_selected.connect(func(index): selected_item_id = list.get_item_metadata(index); refresh_craft_actions())
	content.add_child(list)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	content.add_child(actions)
	refresh_craft_actions()

func refresh_craft_actions() -> void:
	var actions = content.get_node_or_null("Actions")
	if actions == null: return
	for child in actions.get_children(): child.queue_free()
	var item = battle.inventory.find_item(selected_item_id)
	if item == null: return
	var dismantle := Button.new()
	dismantle.text = "分解"
	dismantle.disabled = battle.crafting.is_equipped(selected_item_id)
	dismantle.pressed.connect(request_dismantle.bind(item))
	actions.add_child(dismantle)
	var affix_select := OptionButton.new()
	for i in range(item.get("affixes", []).size()):
		affix_select.add_item("词条%d：%s" % [i + 1, item.affixes[i].stat])
		affix_select.set_item_metadata(i, i)
	affix_select.item_selected.connect(func(i): selected_affix = i)
	actions.add_child(affix_select)
	var reroll := Button.new()
	reroll.text = "消耗材料生成候选"
	reroll.disabled = item.get("affixes", []).is_empty()
	reroll.pressed.connect(begin_reroll)
	actions.add_child(reroll)

func request_dismantle(item: Dictionary) -> void:
	if int(item.quality_rank) >= 3:
		pending_dismantle = item.instance_id
		confirm_dialog.dialog_text = "确定分解 %s？此操作不可撤销。" % item.name
		confirm_dialog.popup_centered()
	else:
		pending_dismantle = item.instance_id
		confirm_dismantle()

func confirm_dismantle() -> void:
	var reward: int = battle.crafting.dismantle(pending_dismantle)
	if reward > 0: battle.log_message.emit("分解成功，获得重铸材料 ×%d" % reward)
	selected_item_id = ""
	refresh()

func begin_reroll() -> void:
	var result: Dictionary = battle.crafting.begin_reroll(selected_item_id, selected_affix)
	if result.is_empty():
		battle.log_message.emit("材料不足或无法重铸")
		return
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "候选：%s %.3f（已扣%d材料）" % [result.candidate.stat, result.candidate.value, result.cost]
	row.add_child(label)
	var accept := Button.new(); accept.text = "接受新词条"; accept.pressed.connect(resolve_reroll.bind(true)); row.add_child(accept)
	var keep := Button.new(); keep.text = "保留旧词条"; keep.pressed.connect(resolve_reroll.bind(false)); row.add_child(keep)
	content.add_child(row)

func resolve_reroll(accept: bool) -> void:
	battle.crafting.resolve_reroll(accept)
	battle.log_message.emit("已%s重铸候选" % ("接受" if accept else "放弃"))
	refresh()

func build_strategy() -> void:
	title.text = "主动 / 被动技能与自动策略"
	var p = battle.progression
	if selected_skill_actor.is_empty() or selected_skill_actor not in p.roster:
		selected_skill_actor = p.roster[0]
	var actor_select := OptionButton.new()
	for actor_id in p.roster:
		actor_select.add_item("Lv.%d　%s" % [p.actor_level(actor_id), battle.actors[actor_id].name])
		actor_select.set_item_metadata(actor_select.item_count - 1, actor_id)
		if actor_id == selected_skill_actor: actor_select.select(actor_select.item_count - 1)
	actor_select.item_selected.connect(func(index): selected_skill_actor = actor_select.get_item_metadata(index); skill_feedback = ""; refresh())
	content.add_child(actor_select)
	var actor: Dictionary = battle.actors[selected_skill_actor]
	var active: Dictionary = battle.skills.get(actor.get("skill", ""), {})
	var passive: Dictionary = battle.passives_config.get(actor.get("passive_skill", actor.get("talent", "")), {})
	var active_level: int = p.skill_level(selected_skill_actor, "active")
	var passive_level: int = p.skill_level(selected_skill_actor, "passive")
	var active_power: float = float(active.get("power", 1.0)) * (1.0 + float(active.get("power_per_level", 0.0)) * (active_level - 1))
	var next_power: float = float(active.get("power", 1.0)) * (1.0 + float(active.get("power_per_level", 0.0)) * active_level)
	var cooldown: float = float(active.get("cooldown", 0.0)) * (1.0 - float(active.get("cooldown_per_level", 0.0)) * (active_level - 1))
	var next_cooldown: float = float(active.get("cooldown", 0.0)) * (1.0 - float(active.get("cooldown_per_level", 0.0)) * active_level)
	var passive_value: float = float(passive.get("value", 0.0)) + float(passive.get("per_level", 0.0)) * (passive_level - 1)
	var next_passive: float = passive_value + float(passive.get("per_level", 0.0))
	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(0, 150)
	detail.text = "[b][color=#72D8FF]主动 · %s　Lv.%d[/color][/b]\n%s\n威力 %.2f → %.2f　冷却 %.2fs → %.2fs\n\n[b][color=#FFD06A]被动 · %s　Lv.%d[/color][/b]\n%s\n效果 %.1f%% → %.1f%%" % [active.get("name", "未配置"), active_level, active.get("description", ""), active_power, next_power, cooldown, next_cooldown, passive.get("name", "未配置"), passive_level, passive.get("description", ""), passive_value * 100.0, next_passive * 100.0]
	content.add_child(detail)
	var upgrades := HBoxContainer.new()
	content.add_child(upgrades)
	for kind in ["active", "passive"]:
		var cost: Dictionary = p.skill_upgrade_cost(selected_skill_actor, kind)
		var button := Button.new()
		button.text = "升级%s（%d金币+%d材料）" % ["主动" if kind == "active" else "被动", int(cost.gold), int(cost.salvage_dust)]
		button.disabled = p.skill_level(selected_skill_actor, kind) >= 10
		button.pressed.connect(_upgrade_selected_skill.bind(kind))
		upgrades.add_child(button)
	var feedback := Label.new()
	feedback.text = skill_feedback if not skill_feedback.is_empty() else "技能升级会立即进入实际战斗计算并自动存档。"
	feedback.add_theme_color_override("font_color", Color("#FFD27A"))
	content.add_child(feedback)
	content.add_child(HSeparator.new())
	var strategy_label := Label.new()
	strategy_label.text = "自动施放策略"
	strategy_label.add_theme_font_size_override("font_size", 17)
	content.add_child(strategy_label)
	var preset := OptionButton.new()
	for name in p.strategy_presets:
		preset.add_item(name)
		preset.set_item_metadata(preset.item_count - 1, name)
		if name == p.active_strategy: preset.select(preset.item_count - 1)
	preset.item_selected.connect(func(i): p.active_strategy = preset.get_item_metadata(i); p.save_to_disk(); refresh())
	content.add_child(preset)
	var data: Dictionary = p.strategy_presets[p.active_strategy]
	for spec in [["自身生命阈值", "self_hp"], ["队友生命阈值", "ally_hp"], ["周围敌人数阈值", "enemy_count"]]:
		var row := HBoxContainer.new(); content.add_child(row)
		var label := Label.new(); label.text = spec[0]; label.custom_minimum_size = Vector2(180, 24); row.add_child(label)
		var spin := SpinBox.new(); spin.min_value = 1 if spec[1] == "enemy_count" else 0.05; spin.max_value = 8 if spec[1] == "enemy_count" else 1.0; spin.step = 1 if spec[1] == "enemy_count" else 0.05; spin.value = data[spec[1]]; spin.value_changed.connect(update_strategy.bind(spec[1])); row.add_child(spin)

func _upgrade_selected_skill(kind: String) -> void:
	if battle.progression.upgrade_skill(selected_skill_actor, kind):
		skill_feedback = "%s的%s技能升级成功，战斗单位已刷新。" % [battle.actors[selected_skill_actor].name, "主动" if kind == "active" else "被动"]
		battle.rebuild_party()
		battle.log_message.emit(skill_feedback)
	else:
		skill_feedback = "升级失败：请检查金币、重铸材料或技能是否已满级。"
	refresh()

func build_stats() -> void:
	title.text = "实时战斗统计"
	var clear := Button.new()
	clear.text = "清空本次统计"
	clear.tooltip_text = "仅重置伤害、治疗、承伤、技能、击杀和统计时间；不影响任何成长与奖励。"
	clear.pressed.connect(_clear_combat_stats)
	content.add_child(clear)
	var snap: Dictionary = battle.stats_snapshot()
	var text := RichTextLabel.new(); text.bbcode_enabled = true; text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = "本场实时统计 %.1f 秒　装备 %d 件　材料 %d 个　收益 %.1f 件/分钟\nDPS = 每秒平均伤害；换地图/重开后从零统计。\n\n" % [snap.duration, snap.resources.equipment, snap.resources.materials, snap.resources_per_minute]
	for actor_id in snap.actors:
		var row: Dictionary = snap.actors[actor_id]
		text.append_text("[b]%s[/b]　伤害 %.0f　DPS %.1f　普攻 %.0f　技能 %.0f　特效 %.0f　治疗 %.0f　承伤 %.0f　技能%d　击杀%d\n" % [battle.actors.get(actor_id, {"name": actor_id}).name, row.damage, row.dps, row.basic, row.skill, row.effect, row.healing, row.taken, row.skills, row.kills])
	content.add_child(text)

func _clear_combat_stats() -> void:
	battle.reset_combat_stats()
	refresh()

func exchange_actor(index: int, list: ItemList) -> void:
	selected_party_actor = str(list.get_item_metadata(index))
	_recruit_selected_actor()

func assign_selected_party(index: int) -> void:
	if battle.progression.set_party_member(index, selected_party_actor):
		recruit_feedback = "%s已放入位置%d，战场已立即更新。" % [battle.actors[selected_party_actor].name, index + 1]
		battle.rebuild_party()
		refresh()

func clear_party_slot(index: int) -> void:
	if battle.progression.set_party_member(index, ""):
		recruit_feedback = "位置%d已清空。" % (index + 1)
		battle.rebuild_party()
		refresh()

func change_party(index: int, select_index: int, select: OptionButton) -> void:
	if battle.progression.set_party_member(index, select.get_item_metadata(select_index)):
		battle.rebuild_party()
		refresh()

func update_strategy(value: float, key: String) -> void:
	battle.progression.strategy_presets[battle.progression.active_strategy][key] = int(value) if key == "enemy_count" else value
	battle.progression.save_to_disk()

func add_separator(text_value: String) -> void:
	var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", 18); content.add_child(label)

func material_name(id: String) -> String:
	return {"three_kingdoms_token": "虎符", "pokemon_token": "精灵结晶"}.get(id, id)
