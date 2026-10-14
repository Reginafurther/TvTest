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
var camp_ui
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
var recruit_world_filter := "全部"
var challenge_tab := "world_boss"
var bulk_sell_min_rank := 0
var bulk_sell_dialog: ConfirmationDialog
var shop_world_filter := "全部"

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
	for spec in [["角色", "party"], ["招募", "recruit"], ["世界", "world"], ["挑战", "challenge"], ["营地", "camp"], ["锻造", "craft"], ["技能", "strategy"], ["暂停", "pause"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(105, 57)
		button.icon = ArtCatalogScript.texture("function_icons", spec[1])
		V035ThemeScript.button(button, "gold" if spec[1] in ["recruit", "boss"] else "cream")
		if spec[1] == "pause":
			button.pressed.connect(_toggle_pause)
		elif spec[1] == "camp":
			button.pressed.connect(_open_camp)
		elif spec[1] in ["party", "strategy"]:
			button.pressed.connect(_open_character_view.bind("growth" if spec[1] == "party" else "skills"))
		else:
			button.pressed.connect(open_view.bind(spec[1]))
		toolbar_root.add_child(button)
		toolbar_buttons[spec[1]] = button
	aux_root = VBoxContainer.new()
	aux_root.add_theme_constant_override("separation", 2)
	add_child(aux_root)
	for spec in [["商店", "shop"], ["奇遇", "encounters"], ["成就", "achievements"], ["收益", "rewards"], ["目标", "objectives"], ["日志", "logs"], ["统计", "stats"]]:
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

func _open_camp() -> void:
	if panel.visible: close_panel()
	if camp_ui != null: camp_ui.open()

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
	bulk_sell_dialog = ConfirmationDialog.new()
	bulk_sell_dialog.title = "确认一键出售未穿戴装备"
	bulk_sell_dialog.confirmed.connect(_confirm_bulk_sell)
	add_child(bulk_sell_dialog)

func open_view(view: String) -> void:
	if character_ui != null and character_ui.panel.visible:
		character_ui.close_panel()
	if inventory_ui != null and inventory_ui.panel.visible:
		inventory_ui.toggle()
	if view == "rift": challenge_tab = "rift"
	elif view == "boss": challenge_tab = "world_boss"
	current_view = "challenge" if view in ["rift", "boss"] else view
	panel.visible = true
	battle.is_paused = view != "encounters"
	battle.battle_state_changed.emit("奇遇交易中 · 自动战斗继续" if view == "encounters" else "功能界面中")
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
		"boss", "rift", "challenge": build_challenge()
		"craft": build_craft()
		"strategy": build_strategy()
		"stats": build_stats()
		"rewards": build_rewards()
		"objectives": build_objectives()
		"logs": build_logs()
		"shop": build_shop()
		"rift": build_rift()
		"encounters": build_encounters()
		"achievements": build_achievements()
	call_deferred("_restore_scroll_position", current_view)

func _restore_scroll_position(view: String) -> void:
	if panel.visible and current_view == view and content_scroll != null:
		content_scroll.scroll_vertical = int(scroll_positions.get(view, 0))

func build_rift() -> void:
	title.text = "四世界动态大秘境"
	var cap: int = battle.adventure.main_stage_cap()
	var intro := Label.new(); intro.text = "当前主线最高已通关地图等级：Lv.%d｜秘境全局开放上限：%d层\n四个世界共享动态开放上限，但进度、首通、词缀池和Boss配置各自独立。" % [cap, cap]; intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(intro)
	for world_id in battle.adventure.config.rift.worlds:
		var world: Dictionary = battle.adventure.config.rift.worlds[world_id]
		var state: Dictionary = battle.progression.rift_progress[world_id]
		var unlocked: bool = battle.adventure.rift_world_unlocked(str(world_id))
		var heading := Label.new(); heading.text = "\n%s｜最高通关%d层｜%s" % [world.name, int(state.highest_clear), "已开放" if unlocked else "需通关主线第%d关" % int(world.required_stage)]; heading.add_theme_font_size_override("font_size", 20); content.add_child(heading)
		var row := HBoxContainer.new(); content.add_child(row)
		var floor_select := SpinBox.new(); floor_select.min_value = 1; floor_select.max_value = maxi(1, cap); floor_select.value = clampi(int(state.selected_floor), 1, maxi(1, cap)); floor_select.custom_minimum_size = Vector2(130, 36); row.add_child(floor_select)
		var auto := CheckBox.new(); auto.text = "自动挑战下一层"; auto.button_pressed = bool(state.auto_climb); auto.toggled.connect(_set_rift_auto.bind(str(world_id))); row.add_child(auto)
		var challenge := Button.new(); challenge.text = "开始挑战"; challenge.disabled = not unlocked or cap <= 0; challenge.pressed.connect(_start_rift_from_selector.bind(str(world_id), floor_select)); row.add_child(challenge)
		var preview_floor := clampi(int(floor_select.value), 1, maxi(1, cap)); var profile: Dictionary = battle.adventure.rift_profile(str(world_id), preview_floor)
		var affix_names: Array[String] = []
		for id in profile.get("affixes", []): affix_names.append(str(battle.adventure.config.rift.affixes[id].name))
		var detail := Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.text = "预览第%d层：生命%d / 攻击%d / 防御%d｜词缀：%s\n首通奖励仅一次；重复刷层仍掉落金币、世界材料和高品质装备。" % [preview_floor, int(profile.get("health", 0)), int(profile.get("attack", 0)), int(profile.get("defense", 0)), "、".join(affix_names) if not affix_names.is_empty() else "无"]; content.add_child(detail)

func _set_rift_auto(enabled: bool, world_id: String) -> void:
	battle.progression.rift_progress[world_id].auto_climb = enabled; battle.progression.save_to_disk()

func _start_rift_from_selector(world_id: String, selector: SpinBox) -> void:
	var floor := int(selector.value)
	if battle.adventure.start_rift(world_id, floor): close_panel()
	else:
		rewards_feedback = "该层未开放：只能挑战主线等级范围内且不超过当前秘境进度+1的层数。"; refresh()

func build_encounters() -> void:
	title.text = "挂机奇遇 · 自动战斗不会暂停"
	var active: Dictionary = battle.adventure.active_encounter
	var status := Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "当前奇遇：无；系统按最短间隔与权重自动触发。" if active.is_empty() else "当前奇遇：%s｜剩余约%d秒" % [battle.adventure.config.encounters.types[str(active.type)].name, int(active.remaining)]
	content.add_child(status)
	if str(active.get("type", "")) == "wandering_merchant":
		var hint := Label.new(); hint.text = "商人库存由本次奇遇序号固定，反复关闭不会刷新。"; content.add_child(hint)
		var stock: Array = battle.progression.encounter_state.get("merchant_stock", [])
		for index in range(stock.size()):
			var row: Dictionary = stock[index]; var button := Button.new(); button.text = "%s ×%d｜%d金币%s" % [row.name, int(row.amount), int(row.price), "｜已售罄" if bool(row.sold) else ""]; button.disabled = bool(row.sold) or battle.progression.gold < int(row.price); button.pressed.connect(_buy_encounter_item.bind(index)); content.add_child(button)
	var log_title := Label.new(); log_title.text = "\n奇遇日志（累计与奖励）"; log_title.add_theme_font_size_override("font_size", 19); content.add_child(log_title)
	for row in battle.progression.encounter_log:
		var reward: Dictionary = row.get("reward", {}); var line := Label.new(); line.text = "%s｜主线Lv.%d｜%s｜金币%d 材料%d" % [row.name, int(row.stage), "完成" if bool(row.success) else "未完成", int(reward.get("gold", 0)), int(reward.get("material", 0))]; content.add_child(line)

func _buy_encounter_item(index: int) -> void:
	if not battle.adventure.buy_merchant_item(index): rewards_feedback = "购买失败：金币不足、商品已售罄或商人已离开。"
	refresh()

func build_achievements() -> void:
	title.text = "冒险成就与收藏奖励"
	for id in battle.adventure.config.achievements:
		var data: Dictionary = battle.adventure.config.achievements[id]; var claimed := bool(battle.progression.achievements.get(id, {}).get("claimed", false)); var ready: bool = battle.adventure.achievement_ready(str(id))
		var button := Button.new(); button.text = "%s｜%s" % [data.name, "已领取" if claimed else "领取" if ready else "未达成"]; button.disabled = claimed or not ready; button.pressed.connect(_claim_achievement.bind(str(id))); content.add_child(button)

func _claim_achievement(id: String) -> void:
	battle.adventure.claim_achievement(id); refresh()

func build_rewards() -> void:
	title.text = "挂机收益"
	var snap: Dictionary = battle.stats_snapshot()
	var info := Label.new()
	var pending: Dictionary = battle.progression.pending_offline
	info.text = "本场自动战斗 %.0f 秒\n获得装备：%d 件　招募材料：%d 个　累计金币：%d\n资源收益估算：%.1f / 分钟\n\n离线挂机（最多8小时）：%d分钟\n待领取：金币%d、虎符%d、精灵结晶%d、龙血结晶%d、江湖令%d" % [snap.duration, snap.resources.equipment, snap.resources.materials, battle.progression.gold, snap.resources_per_minute, int(pending.get("seconds", 0)) / 60, int(pending.get("gold", 0)), int(pending.get("three_kingdoms_token", 0)), int(pending.get("pokemon_token", 0)), int(pending.get("dragon_blood_crystal", 0)), int(pending.get("jianghu_token", 0))]
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
		rewards_feedback = "领取成功：金币%d、虎符%d、精灵结晶%d、龙血结晶%d、江湖令%d。" % [int(result.gold), int(result.three_kingdoms_token), int(result.pokemon_token), int(result.get("dragon_blood_crystal", 0)), int(result.get("jianghu_token", 0))]
		battle.log_message.emit(rewards_feedback)
	refresh()

func build_objectives() -> void:
	title.text = "关卡目标"
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "当前地图：%s\n\n挂机击败怪物并自动拾取装备、金币、经验与世界材料。\n在统一角色页换装、查看成长并配置主动/被动技能。\n按全局1—40关推进；第10/20/30关依次开放后续世界。" % battle.worlds_config.maps[battle.current_map_id].name
	if not battle.progression.guide_finished:
		var step: int = clampi(battle.progression.guide_step, 0, 5)
		info.text = "当前引导：%d/6\n\n%s" % [step + 1, ["用虎符定向招募", "将输出角色上阵", "观察职业自动战斗", "等待装备掉落", "穿戴一件装备", "补齐四人编队"][step]]
	info.add_theme_font_size_override("font_size", 19)
	content.add_child(info)
	var auto_push := CheckButton.new()
	auto_push.text = "通关后自动进入下一关（第40关后持续重复）"
	auto_push.button_pressed = battle.progression.auto_push
	auto_push.toggled.connect(func(enabled: bool): battle.set_auto_push(enabled))
	content.add_child(auto_push)

func build_logs() -> void:
	title.text = "战斗日志"
	log_lines.assign(battle.combat_log)
	var text_view := RichTextLabel.new()
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.custom_minimum_size = Vector2(0, 410)
	text_view.text = "\n".join(log_lines)
	content.add_child(text_view)
	var clear := Button.new(); clear.text = "清空日志（不影响战斗统计）"; clear.pressed.connect(_clear_battle_log); content.add_child(clear)

func _clear_battle_log() -> void:
	battle.clear_combat_log()
	log_lines.assign(battle.combat_log)
	refresh()

func build_shop() -> void:
	title.text = "万界行商 · 买入与出售"
	var summary := Label.new()
	summary.text = "金币：%d　背包：%d/%d　%s" % [battle.progression.gold, battle.inventory.items.size(), battle.inventory.capacity, battle.shop_config.get("rules", {}).get("sell_ratio_hint", "")]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(summary)
	var world_filters := HBoxContainer.new(); content.add_child(world_filters)
	for world in ["全部", "三国", "宝可梦", "龙族", "逆水寒"]:
		var filter := Button.new(); filter.text = world; filter.disabled = shop_world_filter == world; filter.pressed.connect(_set_shop_world.bind(world)); world_filters.add_child(filter)
	var products := ItemList.new()
	products.custom_minimum_size = Vector2(0, 145)
	for product_id in battle.shop_config.get("products", {}):
		var product: Dictionary = battle.shop_config.products[product_id]
		var product_world := str(product.get("world", ""))
		if product_world.is_empty():
			if str(product_id).begins_with("three_") or str(product_id).begins_with("book_triple") or str(product_id).begins_with("book_iron"): product_world = "三国"
			elif str(product_id).begins_with("pokemon") or str(product_id).begins_with("book_thunder") or str(product_id).begins_with("book_regenerator"): product_world = "宝可梦"
		if shop_world_filter != "全部" and product_world != shop_world_filter: continue
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
	var bulk_row := HBoxContainer.new(); content.add_child(bulk_row)
	var bulk_quality := OptionButton.new()
	for value in ["全部品质", "绿色及以上", "蓝色及以上", "紫色及以上", "橙色"]: bulk_quality.add_item(value)
	bulk_quality.selected = clampi(bulk_sell_min_rank, 0, 4)
	bulk_quality.item_selected.connect(func(index): bulk_sell_min_rank = index)
	bulk_row.add_child(bulk_quality)
	var bulk := Button.new(); bulk.text = "一键出售未穿戴装备"; bulk.pressed.connect(_preview_bulk_sell); bulk_row.add_child(bulk)
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

func _set_shop_world(world: String) -> void:
	shop_world_filter = world
	refresh()

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

func _preview_bulk_sell() -> void:
	var preview: Dictionary = battle.shop.bulk_sell_preview(bulk_sell_min_rank)
	if int(preview.count) <= 0:
		shop_feedback = "没有符合品质条件的未穿戴、未锁定装备。"; refresh(); return
	var warning := "\n\n警告：包含橙色高品质装备！" if bool(preview.has_orange) else ""
	bulk_sell_dialog.dialog_text = "将出售%d件装备，预计获得%d金币。\n品质统计：%s%s\n\n提交时会再次校验所有角色的穿戴、锁定与物品实例。" % [int(preview.count), int(preview.gold), str(preview.qualities), warning]
	bulk_sell_dialog.popup_centered()

func _confirm_bulk_sell() -> void:
	var result: Dictionary = battle.shop.bulk_sell(bulk_sell_min_rank)
	shop_feedback = battle.shop.last_error if result.is_empty() else "一键出售成功：%d件，获得%d金币。" % [int(result.count), int(result.gold)]
	if not result.is_empty(): battle.log_message.emit(shop_feedback)
	refresh()

func build_world() -> void:
	title.text = "40关主线 · 四世界冒险"
	var info := Label.new()
	info.text = "当前：%s　｜世界解锁：三国%s 宝可梦%s 龙族%s 逆水寒%s" % [battle.worlds_config.maps[battle.current_map_id].name, "✓", "✓" if battle.progression.world_unlocked("宝可梦") else "🔒", "✓" if battle.progression.world_unlocked("龙族") else "🔒", "✓" if battle.progression.world_unlocked("逆水寒") else "🔒"]
	content.add_child(info)
	for map_id in battle.worlds_config.maps:
		var data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(data.get("global_stage", 1))
		var complete: bool = battle.progression.is_stage_complete(stage)
		var available: bool = battle.progression.can_enter_stage(stage)
		var button := Button.new()
		var state := "已通关" if complete else "可挑战" if available else "世界锁定" if not battle.progression.world_unlocked(str(data.world)) else "前置未通关"
		button.text = "%s · 全局第%d关 · %s（难度Lv.%d） · %s" % [data.world, stage, data.name, int(data.get("difficulty_level", stage)), state]
		button.disabled = (map_id == battle.current_map_id and battle.active_boss_id.is_empty() and not battle.stage_cleared) or not available
		button.tooltip_text = "按全局1—40关顺序推进；角色等级上限随最高已通关主线开放。"
		button.pressed.connect(_enter_stage.bind(map_id))
		content.add_child(button)

func _enter_stage(map_id: String) -> void:
	if battle.switch_map(map_id):
		close_panel()

func build_challenge() -> void:
	title.text = "挑战 · Boss与大秘境"
	var tabs := HBoxContainer.new(); content.add_child(tabs)
	for spec in [["世界Boss", "world_boss"], ["主线Boss重战", "story_boss"], ["大秘境", "rift"]]:
		var button := Button.new(); button.text = spec[0]; button.disabled = challenge_tab == spec[1]; button.pressed.connect(_set_challenge_tab.bind(spec[1])); tabs.add_child(button)
	if challenge_tab == "rift":
		build_rift()
	elif challenge_tab == "story_boss":
		var hint := Label.new(); hint.text = "选择已通关主线关卡重战；不会重复发放首通奖励。"; content.add_child(hint)
		for map_id in battle.worlds_config.maps:
			var data: Dictionary = battle.worlds_config.maps[map_id]
			var stage := int(data.get("global_stage", 1))
			if not battle.progression.is_stage_complete(stage): continue
			var button := Button.new(); button.text = "%s · 第%d关 · %s" % [data.world, stage, data.get("boss_name", "关底Boss")]; button.pressed.connect(_enter_stage.bind(map_id)); content.add_child(button)
	else:
		build_boss()

func _set_challenge_tab(value: String) -> void:
	challenge_tab = value
	refresh()

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
	info.text = "虎符%d　精灵结晶%d　龙血结晶%d　江湖令%d　已招募%d/36" % [p.materials.three_kingdoms_token, p.materials.pokemon_token, p.materials.dragon_blood_crystal, p.materials.jianghu_token, p.roster.size()]
	content.add_child(info)
	var filters := HBoxContainer.new(); content.add_child(filters)
	for world in ["全部", "三国", "宝可梦", "龙族", "逆水寒"]:
		var filter := Button.new(); filter.text = world; filter.disabled = recruit_world_filter == world; filter.pressed.connect(_set_recruit_world.bind(world)); filters.add_child(filter)
	recruit_detail = Label.new()
	recruit_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	recruit_detail.text = recruit_feedback if not recruit_feedback.is_empty() else "单击角色查看详情，再点击明确的招募按钮；选择不会刷新或跳回顶部。"
	recruit_detail.add_theme_color_override("font_color", Color("#FFD27A"))
	content.add_child(recruit_detail)
	recruit_list = ItemList.new()
	recruit_list.custom_minimum_size = Vector2(0, 185)
	for actor_id in battle.worlds_config.recruitment.costs:
		if recruit_world_filter != "全部" and str(battle.actors.get(actor_id, {}).get("world", "")) != recruit_world_filter: continue
		var cost: Array = battle.worlds_config.recruitment.costs[actor_id]
		var owned: bool = actor_id in p.roster
		var legendary_gate := {"lu_bu":"lu_bu", "mewtwo":"mewtwo", "zero":"nidhogg", "nine_spirits":"liuxingwen"}
		var legendary_locked: bool = legendary_gate.has(actor_id) and not bool(p.boss_first_clear.get(legendary_gate[actor_id], false))
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

func _set_recruit_world(world: String) -> void:
	recruit_world_filter = world
	refresh()

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
	var legendary_gate := {"lu_bu":"lu_bu", "mewtwo":"mewtwo", "zero":"nidhogg", "nine_spirits":"liuxingwen"}
	var legendary_locked: bool = legendary_gate.has(selected_party_actor) and not bool(p.boss_first_clear.get(legendary_gate[selected_party_actor], false))
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
	return {"three_kingdoms_token":"虎符", "pokemon_token":"精灵结晶", "dragon_blood_crystal":"龙血结晶", "jianghu_token":"江湖令", "salvage_dust":"重铸材料"}.get(id, id)
