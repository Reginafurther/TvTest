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
var toolbar_buttons: Dictionary = {}
var inventory_ui
var character_ui
var toolbar_root: GridContainer
var aux_root: ScrollContainer
var aux_list: VBoxContainer
var log_lines: Array[String] = []
var recruit_feedback := ""
var refresh_pending := false
var selected_shop_product := ""
var selected_shop_item := ""
var shop_quantity := 1
var shop_feedback := ""
var rewards_feedback := ""
var shop_icon_cache: Dictionary = {}
var selected_party_actor := ""
var scroll_positions: Dictionary = {}
var recruit_list: ItemList
var recruit_detail: Label
var recruit_button: Button
var recruit_list_scroll := 0.0
var recruit_world_filter := "全部"
var bulk_sell_min_rank := 0
var bulk_sell_dialog: ConfirmationDialog
var reset_dialog: ConfirmationDialog
var shop_world_filter := "全部"
var stats_refresh_timer := 0.0
var stats_summary: RichTextLabel
var stats_rows_box: VBoxContainer
var stats_actor_rows: Dictionary = {}
var stats_sort_mode := "DPS"
var stats_expanded: Dictionary = {}
var difficulty_preview := 1.0
var settings_feedback := ""
var auto_equipment_warning_dialog: ConfirmationDialog
var pending_auto_equipment_setting: Dictionary = {}
var selected_world_tab := ""
var pause_before_open := false

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
	backpack_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar_root.add_child(backpack_space)
	for spec in [["角色", "party"], ["招募", "recruit"], ["世界", "world"], ["挑战", "challenge"], ["锻造", "craft"], ["图鉴", "codex"], ["暂停", "pause"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(105, 57)
		button.icon = ArtCatalogScript.texture("function_icons", spec[1])
		V035ThemeScript.button(button, "gold" if spec[1] in ["recruit", "boss"] else "cream")
		if spec[1] == "pause":
			button.pressed.connect(_toggle_pause)
		elif spec[1] == "party":
			button.pressed.connect(_open_character_view.bind("growth"))
		else:
			button.pressed.connect(open_view.bind(spec[1]))
		toolbar_root.add_child(button)
		toolbar_buttons[spec[1]] = button
	aux_root = ScrollContainer.new()
	aux_root.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	aux_root.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	aux_root.mouse_filter = Control.MOUSE_FILTER_STOP
	aux_root.follow_focus = true
	add_child(aux_root)
	aux_list = VBoxContainer.new()
	aux_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aux_list.add_theme_constant_override("separation", 2)
	aux_root.add_child(aux_list)
	for spec in [["商店", "shop"], ["奇遇", "encounters"], ["成就", "achievements"], ["收益", "rewards"], ["挂机设置", "objectives"], ["日志", "logs"], ["战斗统计", "stats"]]:
		var button := Button.new()
		button.text = spec[0]
		button.custom_minimum_size = Vector2(115, 27)
		V035ThemeScript.button(button, "gold" if spec[1] == "shop" else "blue")
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(open_view.bind(spec[1]))
		aux_list.add_child(button)
		toolbar_buttons[spec[1]] = button

func apply_layout(viewport_size: Vector2, factor: float, offset_x: float, footer_y: float) -> void:
	toolbar_root.position = Vector2(offset_x + 864 * factor, footer_y + 12 * factor)
	toolbar_root.scale = Vector2.ONE * factor
	aux_root.position = Vector2(offset_x + 1305 * factor, footer_y + 12 * factor)
	aux_root.size = Vector2(125, maxf(72.0, (viewport_size.y - footer_y - 22.0 * factor) / maxf(0.01, factor)))
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
	bulk_sell_dialog = ConfirmationDialog.new()
	bulk_sell_dialog.title = "确认一键出售未穿戴装备"
	bulk_sell_dialog.confirmed.connect(_confirm_bulk_sell)
	add_child(bulk_sell_dialog)
	reset_dialog = ConfirmationDialog.new()
	reset_dialog.title = "二次确认：备份并重新开始"
	reset_dialog.dialog_text = "系统将先完整备份并校验现有存档，然后重置角色、装备、技能、主线、秘境与成就。\n\n备份失败时绝不会执行重置。此操作完成后将重新载入游戏。"
	reset_dialog.ok_button_text = "确认备份并重新开始"
	reset_dialog.cancel_button_text = "取消"
	reset_dialog.confirmed.connect(_confirm_safe_reset)
	add_child(reset_dialog)
	auto_equipment_warning_dialog = ConfirmationDialog.new()
	auto_equipment_warning_dialog.title = "确认自动处理稀有装备"
	auto_equipment_warning_dialog.ok_button_text = "我了解风险，继续"
	auto_equipment_warning_dialog.cancel_button_text = "取消"
	auto_equipment_warning_dialog.confirmed.connect(_confirm_auto_equipment_setting)
	auto_equipment_warning_dialog.canceled.connect(_cancel_auto_equipment_setting)
	add_child(auto_equipment_warning_dialog)

func open_view(view: String) -> void:
	if character_ui != null and character_ui.panel.visible:
		character_ui.close_panel()
	if inventory_ui != null and inventory_ui.panel.visible:
		inventory_ui.toggle()
	current_view = "challenge" if view in ["rift", "boss"] else view
	if not panel.visible: pause_before_open = battle.is_paused
	panel.visible = true
	if view not in ["encounters", "stats"]: battle.is_paused = true
	battle.battle_state_changed.emit("战斗统计中 · 自动战斗继续" if view == "stats" else "奇遇交易中 · 自动战斗继续" if view == "encounters" else "功能界面中")
	refresh()
	if current_view == "stats": stats_refresh_timer = 0.0

func _open_character_view(tab_name: String) -> void:
	if panel.visible: close_panel()
	if character_ui != null: character_ui.open(tab_name)

func close_panel() -> void:
	panel.visible = false
	battle.is_paused = pause_before_open
	battle.battle_state_changed.emit("已暂停" if battle.is_paused else "自动战斗中")

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func refresh_if_open() -> void:
	if panel.visible and current_view == "stats":
		return
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
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	match current_view:
		"world": build_world()
		"recruit", "party": build_recruit()
		"boss", "rift", "challenge": build_challenge()
		"craft": build_craft()
		"codex": build_codex()
		"stats": build_stats()
		"rewards": build_rewards()
		"objectives": build_objectives()
		"logs": build_logs()
		"shop": build_shop()
		"rift": build_rift()
		"encounters": build_encounters()
		"achievements": build_achievements()
		"settings": build_settings()
	call_deferred("_restore_scroll_position", current_view)

func _process(delta: float) -> void:
	if panel == null or not panel.visible or current_view != "stats":
		return
	stats_refresh_timer -= delta
	if stats_refresh_timer <= 0.0:
		stats_refresh_timer = 0.75
		update_stats_view()

func _restore_scroll_position(view: String) -> void:
	if panel.visible and current_view == view and content_scroll != null:
		content_scroll.scroll_vertical = int(scroll_positions.get(view, 0))

func build_rift() -> void:
	title.text = "挑战 · 十世界大秘境"
	var cap: int = battle.adventure.main_stage_cap()
	var intro := Label.new(); intro.text = "当前主线最高已通关地图等级：Lv.%d｜秘境全局开放上限：%d层\n十个世界共享统一Boss成长曲线；装备固定为紫色80%%、橙色10%%、本世界红装10%%。" % [cap, cap]; intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(intro)
	for world_id in battle.adventure.config.rift.worlds:
		var world: Dictionary = battle.adventure.config.rift.worlds[world_id]
		var state: Dictionary = battle.progression.rift_progress[world_id]
		var unlocked: bool = battle.adventure.rift_world_unlocked(str(world_id))
		var heading := Label.new(); heading.text = "\n%s｜最高通关%d层｜当前选择%d层｜%s" % [world.name, int(state.highest_clear), int(state.selected_floor), "已开放" if unlocked else "需通关主线第%d关" % int(world.required_stage)]; heading.add_theme_font_size_override("font_size", 20); content.add_child(heading)
		var row := HBoxContainer.new(); content.add_child(row)
		var selectable_max := mini(cap, int(state.highest_clear) if bool(state.get("repeat_floor", false)) else int(state.highest_clear) + 1)
		var floor_select := SpinBox.new(); floor_select.min_value = 1; floor_select.max_value = maxi(1, selectable_max); floor_select.value = clampi(int(state.selected_floor), 1, maxi(1, selectable_max)); floor_select.custom_minimum_size = Vector2(130, 36); floor_select.value_changed.connect(_set_rift_floor.bind(str(world_id))); row.add_child(floor_select)
		var challenge := Button.new(); challenge.text = "开始挑战"; challenge.disabled = not unlocked or cap <= 0; challenge.pressed.connect(_start_rift_from_selector.bind(str(world_id), floor_select)); row.add_child(challenge)
		var modes := FlowContainer.new(); content.add_child(modes)
		var auto := CheckBox.new(); auto.text = "自动挑战下一层"; auto.button_pressed = bool(state.auto_climb); auto.toggled.connect(_set_rift_auto.bind(str(world_id))); modes.add_child(auto)
		var repeat := CheckBox.new(); repeat.text = "固定层数重复刷"; repeat.button_pressed = bool(state.get("repeat_floor", false)); repeat.disabled = int(state.highest_clear) <= 0; repeat.toggled.connect(_set_rift_repeat.bind(str(world_id))); modes.add_child(repeat)
		var stop := Button.new(); stop.text = "停止自动循环"; stop.disabled = not bool(state.auto_climb) and not bool(state.get("repeat_floor", false)); stop.pressed.connect(_stop_rift_loop.bind(str(world_id))); modes.add_child(stop)
		var preview_floor := clampi(int(floor_select.value), 1, maxi(1, cap)); var profile: Dictionary = battle.adventure.rift_profile(str(world_id), preview_floor)
		var affix_names: Array[String] = []
		for id in profile.get("affixes", []): affix_names.append(str(battle.adventure.config.rift.affixes[id].name))
		var detail := Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.text = "预览第%d层：生命%d / 攻击%d / 防御%d｜词缀：%s\n首通奖励仅一次；固定刷层只接受已通关层，并保持当前层数。" % [preview_floor, int(profile.get("health", 0)), int(profile.get("attack", 0)), int(profile.get("defense", 0)), "、".join(affix_names) if not affix_names.is_empty() else "无"]; content.add_child(detail)

func _set_rift_auto(enabled: bool, world_id: String) -> void:
	battle.progression.set_rift_mode(world_id, "climb" if enabled else "manual"); refresh()

func _set_rift_repeat(enabled: bool, world_id: String) -> void:
	battle.progression.set_rift_mode(world_id, "repeat" if enabled else "manual"); refresh()

func _stop_rift_loop(world_id: String) -> void:
	battle.progression.set_rift_mode(world_id, "manual"); refresh()

func _set_rift_floor(value: float, world_id: String) -> void:
	battle.progression.set_rift_selected_floor(world_id, int(value))

func _start_rift_from_selector(world_id: String, selector: SpinBox) -> void:
	var floor := int(selector.value)
	if battle.adventure.start_rift(world_id, floor): close_panel()
	else:
		rewards_feedback = "该层未开放：爬层最多选择当前进度+1；固定刷层只能选择已经通关的层数。"; refresh()

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
	info.text = "本场自动战斗 %.0f 秒\n获得装备：%d 件　招募/重铸材料：%d 个　累计金币：%d\n自动出售：%d件 / 金币%d　自动分解：%d件 / 材料%d\n资源收益估算：%.1f / 分钟\n\n离线挂机（最多8小时）：%d分钟\n待领取：金币%d、虎符%d、精灵结晶%d、龙血结晶%d、江湖令%d、徽记%d、侠义令%d、苍龙令%d、忍界卷轴%d、战神令%d、风云令%d" % [snap.duration, snap.resources.equipment, snap.resources.materials, battle.progression.gold, int(snap.resources.get("auto_sold_count", 0)), int(snap.resources.get("auto_sold_gold", 0)), int(snap.resources.get("auto_dismantled_count", 0)), int(snap.resources.get("auto_dismantled_material", 0)), snap.resources_per_minute, int(pending.get("seconds", 0)) / 60, int(pending.get("gold", 0)), int(pending.get("three_kingdoms_token", 0)), int(pending.get("pokemon_token", 0)), int(pending.get("dragon_blood_crystal", 0)), int(pending.get("jianghu_token", 0)), int(pending.get("azeroth_token", 0)), int(pending.get("wuxia_token", 0)), int(pending.get("qin_moon_token", 0)), int(pending.get("ninja_scroll", 0)), int(pending.get("huangyi_token", 0)), int(pending.get("fengyun_token", 0))]
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
		rewards_feedback = "领取成功：金币%d、虎符%d、精灵结晶%d、龙血结晶%d、江湖令%d、徽记%d、侠义令%d、苍龙令%d、忍界卷轴%d、战神令%d、风云令%d。" % [int(result.gold), int(result.three_kingdoms_token), int(result.pokemon_token), int(result.get("dragon_blood_crystal", 0)), int(result.get("jianghu_token", 0)), int(result.get("azeroth_token", 0)), int(result.get("wuxia_token", 0)), int(result.get("qin_moon_token", 0)), int(result.get("ninja_scroll", 0)), int(result.get("huangyi_token", 0)), int(result.get("fengyun_token", 0))]
		battle.log_message.emit(rewards_feedback)
	refresh()

func build_objectives() -> void:
	title.text = "挂机设置"
	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.text = "当前地图：%s\n\n挂机击败怪物并自动拾取装备、金币、经验与世界材料。\n在统一角色页换装、查看成长并配置主动/被动技能。\n按全局1—100关推进；每10关依次开放下一世界。" % battle.worlds_config.maps[battle.current_map_id].name
	if not battle.progression.guide_finished:
		var step: int = clampi(battle.progression.guide_step, 0, 5)
		info.text = "当前引导：%d/6\n\n%s" % [step + 1, ["用虎符定向招募", "将输出角色上阵", "观察职业自动战斗", "等待装备掉落", "穿戴一件装备", "补齐四人编队"][step]]
	info.add_theme_font_size_override("font_size", 19)
	content.add_child(info)
	var auto_push := CheckButton.new()
	auto_push.text = "通关后自动进入下一关（第100关后持续重复）"
	auto_push.button_pressed = battle.progression.auto_push
	auto_push.toggled.connect(func(enabled: bool): battle.set_auto_push(enabled))
	content.add_child(auto_push)
	var p = battle.progression
	var preset_label := Label.new(); preset_label.text = "自动战斗策略"; preset_label.add_theme_font_size_override("font_size", 18); content.add_child(preset_label)
	var preset := OptionButton.new()
	for name in p.strategy_presets:
		preset.add_item(name); preset.set_item_metadata(preset.item_count - 1, name)
		if name == p.active_strategy: preset.select(preset.item_count - 1)
	preset.item_selected.connect(func(i): p.active_strategy = str(preset.get_item_metadata(i)); p.save_to_disk(); refresh())
	content.add_child(preset)
	var data: Dictionary = p.strategy_presets[p.active_strategy]
	for spec in [["自身生命阈值", "self_hp"], ["队友生命阈值", "ally_hp"], ["周围敌人数阈值", "enemy_count"]]:
		var row := HBoxContainer.new(); content.add_child(row)
		var label := Label.new(); label.text = spec[0]; label.custom_minimum_size = Vector2(180, 24); row.add_child(label)
		var spin := SpinBox.new(); spin.min_value = 1 if spec[1] == "enemy_count" else 0.05; spin.max_value = 8 if spec[1] == "enemy_count" else 1.0; spin.step = 1 if spec[1] == "enemy_count" else 0.05; spin.value = float(data.get(spec[1], 1)); spin.value_changed.connect(update_strategy.bind(spec[1])); row.add_child(spin)
	var priority_title := Label.new(); priority_title.text = "上阵角色技能释放优先级"; priority_title.add_theme_font_size_override("font_size", 18); content.add_child(priority_title)
	for actor_id in p.party:
		if str(actor_id).is_empty(): continue
		var row := HBoxContainer.new(); content.add_child(row)
		var label := Label.new(); label.text = battle.actor_display_name(str(actor_id)); label.custom_minimum_size = Vector2(150, 28); row.add_child(label)
		var select := OptionButton.new(); select.add_item("专属优先"); select.add_item("通用优先")
		select.selected = 0 if p.skill_priorities.get(actor_id, ["exclusive", "general"])[0] == "exclusive" else 1
		select.item_selected.connect(_set_party_skill_priority.bind(str(actor_id))); row.add_child(select)
		var ai := Label.new(); ai.text = _idle_ai_description(battle.actors.get(actor_id, {})); ai.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ai.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(ai)

func _set_party_skill_priority(index: int, actor_id: String) -> void:
	battle.progression.set_skill_priority(actor_id, index == 0)
	battle.rebuild_party()

func _idle_ai_description(data: Dictionary) -> String:
	if str(data.get("basic_action", "")) == "heal" or str(data.get("combat_role", "")) == "healer": return "后排治疗低生命队友，受威胁时后撤。"
	if str(data.get("combat_role", "")) == "tank": return "前排接敌并保护队友。"
	if str(data.get("combat_style", "")) == "ranged": return "保持安全距离进行远程输出或辅助。"
	return "主动接近目标进行近战输出。"

func build_codex() -> void:
	title.text = "世界传说装备图鉴"
	var intro := Label.new(); intro.text = "各世界大秘境独有红色传说装备（固定专属词条不占普通词条数量）"; intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(intro)
	var drops: Dictionary = battle.adventure.config.get("rift", {}).get("legendary_drops", {})
	for world_id in drops:
		var item: Dictionary = drops[world_id]
		var world_name := str(battle.adventure.config.get("rift", {}).get("worlds", {}).get(world_id, {}).get("name", world_id)).replace("大秘境", "")
		var slot_name := str(battle.equipment_config.get("slots", {}).get(item.get("slot", ""), item.get("slot", "")))
		var line := Label.new(); line.text = "%s｜%s｜%s｜%s" % [world_name, item.get("name", "未知传说"), slot_name, item.get("affix_name", "")]; line.add_theme_color_override("font_color", Color("#D84A4A")); line.add_theme_font_size_override("font_size", 18); content.add_child(line)

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
	var world_filters := FlowContainer.new(); content.add_child(world_filters)
	for world in ["全部", "三国", "宝可梦", "龙族", "逆水寒", "魔兽世界", "金庸", "秦时明月", "火影忍者", "黄易", "风云"]:
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
	var maps_by_world: Dictionary = {}
	var world_first_stage: Dictionary = {}
	var maximum_stage := 0
	for map_id in battle.worlds_config.maps:
		var map_data: Dictionary = battle.worlds_config.maps[map_id]
		var world_name := str(map_data.get("world", "未知世界"))
		var stage := int(map_data.get("global_stage", 1))
		maximum_stage = maxi(maximum_stage, stage)
		if not maps_by_world.has(world_name): maps_by_world[world_name] = []
		maps_by_world[world_name].append({"id":str(map_id), "data":map_data})
		world_first_stage[world_name] = mini(int(world_first_stage.get(world_name, stage)), stage)
	var world_names: Array = maps_by_world.keys()
	world_names.sort_custom(func(a, b): return int(world_first_stage[a]) < int(world_first_stage[b]))
	var current_world := str(battle.worlds_config.maps.get(battle.current_map_id, {}).get("world", ""))
	if selected_world_tab.is_empty() or (selected_world_tab != "全部" and not maps_by_world.has(selected_world_tab)): selected_world_tab = current_world
	if selected_world_tab.is_empty() and not world_names.is_empty(): selected_world_tab = str(world_names[0])
	title.text = "%d关主线 · %d世界冒险" % [maximum_stage, world_names.size()]
	# The outer panel stays fixed; only the stage list below the horizontal world
	# tabs scrolls vertically.
	content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var info := Label.new()
	var selected_locked: bool = selected_world_tab != "全部" and not battle.progression.world_unlocked(selected_world_tab)
	info.text = "当前战斗：%s　｜正在查看：%s%s" % [str(battle.worlds_config.maps.get(battle.current_map_id, {}).get("name", "未知关卡")), selected_world_tab, "（未解锁，可预览）" if selected_locked else ""]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var navigation_row := HBoxContainer.new()
	navigation_row.name = "WorldNavigationRow"
	navigation_row.add_theme_constant_override("separation", 5)
	content.add_child(navigation_row)
	var previous_world := Button.new()
	previous_world.name = "WorldNavigationPrevious"
	previous_world.text = "‹"
	previous_world.tooltip_text = "向左浏览世界"
	previous_world.custom_minimum_size = Vector2(34, 38)
	previous_world.focus_mode = Control.FOCUS_NONE
	V035ThemeScript.button(previous_world, "cream")
	navigation_row.add_child(previous_world)
	var world_scroll := ScrollContainer.new()
	world_scroll.name = "WorldNavigation"
	world_scroll.custom_minimum_size = Vector2(0, 44)
	world_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	world_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	world_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	world_scroll.follow_focus = false
	navigation_row.add_child(world_scroll)
	var world_tabs := HBoxContainer.new()
	world_tabs.name = "WorldTabs"
	world_tabs.add_theme_constant_override("separation", 6)
	world_scroll.add_child(world_tabs)
	var navigation_names: Array = ["全部"]
	navigation_names.append_array(world_names)
	var selected_world_button: Button = null
	for world_name in navigation_names:
		var tab := Button.new()
		var unlocked: bool = str(world_name) == "全部" or battle.progression.world_unlocked(str(world_name))
		tab.text = str(world_name) + ("" if unlocked else " 🔒")
		tab.custom_minimum_size = Vector2(104, 36)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.focus_mode = Control.FOCUS_NONE
		V035ThemeScript.button(tab, "gold" if str(world_name) == selected_world_tab else "blue")
		tab.pressed.connect(_select_world_tab.bind(str(world_name)))
		world_tabs.add_child(tab)
		if str(world_name) == selected_world_tab: selected_world_button = tab
	var next_world := Button.new()
	next_world.name = "WorldNavigationNext"
	next_world.text = "›"
	next_world.tooltip_text = "向右浏览世界"
	next_world.custom_minimum_size = Vector2(34, 38)
	next_world.focus_mode = Control.FOCUS_NONE
	V035ThemeScript.button(next_world, "cream")
	navigation_row.add_child(next_world)
	previous_world.pressed.connect(_scroll_world_navigation.bind(world_scroll, -1))
	next_world.pressed.connect(_scroll_world_navigation.bind(world_scroll, 1))
	world_scroll.gui_input.connect(_world_navigation_input.bind(world_scroll))
	if selected_world_button != null:
		call_deferred("_ensure_world_button_visible", world_scroll, selected_world_button)
	var stage_scroll := ScrollContainer.new()
	stage_scroll.name = "WorldStageScroll"
	stage_scroll.custom_minimum_size = Vector2(0, 365)
	stage_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	stage_scroll.follow_focus = false
	stage_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(stage_scroll)
	var stage_list := VBoxContainer.new()
	stage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_list.add_theme_constant_override("separation", 6)
	stage_scroll.add_child(stage_list)
	var selected_maps: Array = []
	if selected_world_tab == "全部":
		for world_name in world_names:
			selected_maps.append_array(maps_by_world.get(world_name, []))
	else:
		selected_maps = maps_by_world.get(selected_world_tab, [])
	selected_maps.sort_custom(func(a, b): return int(a.data.get("global_stage", 1)) < int(b.data.get("global_stage", 1)))
	for row in selected_maps:
		var map_id := str(row.id)
		var data: Dictionary = row.data
		var stage := int(data.get("global_stage", 1))
		var complete: bool = battle.progression.is_stage_complete(stage)
		var available: bool = battle.progression.can_enter_stage(stage)
		var button := Button.new()
		var state := "已通关" if complete else "可挑战" if available else "世界锁定" if not battle.progression.world_unlocked(str(data.world)) else "前置未通关"
		button.text = "全局第%d关 · %s（难度Lv.%d） · %s" % [stage, data.name, int(data.get("difficulty_level", stage)), state]
		button.disabled = (map_id == battle.current_map_id and battle.active_boss_id.is_empty() and not battle.stage_cleared) or not available
		button.tooltip_text = "按全局主线顺序推进；切换分类仅预览，不会切换当前战斗。"
		button.pressed.connect(_enter_stage.bind(map_id))
		stage_list.add_child(button)

func _scroll_world_navigation(scroll: ScrollContainer, direction: int) -> void:
	if not is_instance_valid(scroll): return
	scroll.scroll_horizontal = maxi(0, scroll.scroll_horizontal + direction * 180)

func _world_navigation_input(event: InputEvent, scroll: ScrollContainer) -> void:
	if not is_instance_valid(scroll) or not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_world_navigation(scroll, -1)
		scroll.accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_world_navigation(scroll, 1)
		scroll.accept_event()

func _ensure_world_button_visible(scroll: ScrollContainer, button: Button) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(button):
		scroll.ensure_control_visible(button)

func _select_world_tab(world_name: String) -> void:
	if selected_world_tab == world_name: return
	selected_world_tab = world_name
	scroll_positions["world"] = 0
	content_scroll.scroll_vertical = 0
	refresh()

func _enter_stage(map_id: String) -> void:
	if battle.switch_map(map_id):
		close_panel()

func build_challenge() -> void:
	build_rift()

func build_recruit() -> void:
	title.text = "角色招募与四人编队" if current_view == "recruit" else "伙伴与四人编队"
	var p = battle.progression
	var info := Label.new()
	info.text = "虎符%d　精灵结晶%d　龙血结晶%d　江湖令%d　徽记%d　侠义令%d　苍龙令%d　忍界卷轴%d　战神令%d　风云令%d　已招募%d/92" % [p.materials.three_kingdoms_token, p.materials.pokemon_token, p.materials.dragon_blood_crystal, p.materials.jianghu_token, p.materials.azeroth_token, p.materials.wuxia_token, p.materials.qin_moon_token, p.materials.ninja_scroll, p.materials.huangyi_token, p.materials.fengyun_token, p.roster.size()]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var filters := FlowContainer.new(); content.add_child(filters)
	for world in ["全部", "三国", "宝可梦", "龙族", "逆水寒", "魔兽世界", "金庸", "秦时明月", "火影忍者", "黄易", "风云"]:
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
		var legendary_gate := {"lu_bu":"lu_bu", "mewtwo":"mewtwo", "zero":"nidhogg", "nine_spirits":"liuxingwen", "hy_ling_donglai":"pang_ban", "fy_di_shitian":"di_shitian"}
		var legendary_locked: bool = legendary_gate.has(actor_id) and not bool(p.boss_first_clear.get(legendary_gate[actor_id], false))
		var state: String = "已招募" if owned else "需先击败对应Boss" if legendary_locked else "%s ×%d" % [material_name(cost[0]), cost[1]]
		var idx := recruit_list.add_item("%s · %s" % [battle.actor_display_name(str(actor_id)), state])
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
		slot_label.text = "位置%d：%s" % [i + 1, battle.actor_display_name(current) if not current.is_empty() else "空位"]
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
	var legendary_gate := {"lu_bu":"lu_bu", "mewtwo":"mewtwo", "zero":"nidhogg", "nine_spirits":"liuxingwen", "hy_ling_donglai":"pang_ban", "fy_di_shitian":"di_shitian"}
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
		var owner: String = battle.inventory.item_owner(str(item.instance_id))
		var wearer := "｜%s穿戴" % battle.actor_display_name(owner) if not owner.is_empty() else ""
		var idx := list.add_item("Lv.%d %s%s" % [item.level, item.name, wearer])
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
		var stat_id := str(item.affixes[i].stat)
		var stat_name := str(battle.equipment_config.get("affixes", {}).get(stat_id, {}).get("name", stat_id))
		affix_select.add_item("词条%d：%s" % [i + 1, stat_name])
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
	var stat_id := str(result.candidate.stat)
	var stat_name := str(battle.equipment_config.get("affixes", {}).get(stat_id, {}).get("name", stat_id))
	label.text = "候选：%s %.3f（已扣%d材料）" % [stat_name, result.candidate.value, result.cost]
	row.add_child(label)
	var accept := Button.new(); accept.text = "接受新词条"; accept.pressed.connect(resolve_reroll.bind(true)); row.add_child(accept)
	var keep := Button.new(); keep.text = "保留旧词条"; keep.pressed.connect(resolve_reroll.bind(false)); row.add_child(keep)
	content.add_child(row)

func resolve_reroll(accept: bool) -> void:
	battle.crafting.resolve_reroll(accept)
	battle.log_message.emit("已%s重铸候选" % ("接受" if accept else "放弃"))
	refresh()

func build_stats() -> void:
	title.text = "战斗统计 · 实时DPS/HPS"
	stats_actor_rows.clear()
	var actions := HBoxContainer.new()
	content.add_child(actions)
	var clear := Button.new()
	clear.text = "清空本次统计"
	clear.tooltip_text = "仅重置伤害、治疗、承伤、技能、击杀和统计时间；不影响任何成长与奖励。"
	clear.pressed.connect(_clear_combat_stats)
	actions.add_child(clear)
	var sort := OptionButton.new()
	for value in ["按DPS排序", "按HPS排序"]: sort.add_item(value)
	sort.selected = 1 if stats_sort_mode == "HPS" else 0
	sort.item_selected.connect(func(index): stats_sort_mode = "HPS" if index == 1 else "DPS"; update_stats_view())
	actions.add_child(sort)
	var live := Label.new(); live.text = "● 每0.75秒刷新 · 关闭页面后仍继续记录"; live.add_theme_color_override("font_color", Color("#8EE6A8")); actions.add_child(live)
	stats_summary = RichTextLabel.new()
	stats_summary.bbcode_enabled = true
	stats_summary.fit_content = true
	stats_summary.custom_minimum_size = Vector2(0, 92)
	content.add_child(stats_summary)
	stats_rows_box = VBoxContainer.new()
	stats_rows_box.add_theme_constant_override("separation", 8)
	content.add_child(stats_rows_box)
	update_stats_view()

func _stats_actor_ids(snapshot: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for actor_id in battle.progression.party:
		var id := str(actor_id)
		if not id.is_empty() and id not in result: result.append(id)
	for actor_id in snapshot.get("actors", {}):
		var id := str(actor_id)
		if id in battle.progression.roster and id not in result: result.append(id)
	return result

func _rebuild_stats_rows(ids: Array[String]) -> void:
	for child in stats_rows_box.get_children(): child.queue_free()
	stats_actor_rows.clear()
	for actor_id in ids:
		var card := VBoxContainer.new()
		var values := RichTextLabel.new()
		values.bbcode_enabled = true
		values.fit_content = true
		values.custom_minimum_size = Vector2(0, 64)
		card.add_child(values)
		var share := ProgressBar.new()
		share.show_percentage = false
		share.max_value = 100.0
		share.custom_minimum_size = Vector2(0, 8)
		card.add_child(share)
		var detail_toggle := Button.new()
		detail_toggle.text = "查看技能伤害"
		detail_toggle.pressed.connect(_toggle_stats_damage_detail.bind(actor_id))
		card.add_child(detail_toggle)
		var detail := RichTextLabel.new()
		detail.bbcode_enabled = true
		detail.fit_content = true
		detail.custom_minimum_size = Vector2(0, 48)
		detail.visible = bool(stats_expanded.get(actor_id, false))
		card.add_child(detail)
		stats_rows_box.add_child(card)
		stats_actor_rows[actor_id] = {"root": card, "values": values, "share": share, "toggle":detail_toggle, "detail":detail}

func _toggle_stats_damage_detail(actor_id: String) -> void:
	stats_expanded[actor_id] = not bool(stats_expanded.get(actor_id, false))
	if stats_actor_rows.has(actor_id):
		stats_actor_rows[actor_id].detail.visible = bool(stats_expanded[actor_id])
	update_stats_view()

func update_stats_view() -> void:
	if stats_summary == null or stats_rows_box == null: return
	var snap: Dictionary = battle.stats_snapshot()
	var ids := _stats_actor_ids(snap)
	if stats_actor_rows.keys().size() != ids.size() or ids.any(func(id): return not stats_actor_rows.has(id)):
		_rebuild_stats_rows(ids)
	ids.sort_custom(func(a, b):
		var key := "hps" if stats_sort_mode == "HPS" else "dps"
		return float(snap.actors.get(a, {}).get(key, 0.0)) > float(snap.actors.get(b, {}).get(key, 0.0)))
	var team: Dictionary = snap.get("team", {})
	stats_summary.text = "[b]统计时长[/b] %.1f秒　[b][color=#FFB86B]队伍伤害[/color][/b] %s　[b]DPS[/b] %s（生命%s / 敌盾%s）\n[b][color=#77E89A]治疗贡献[/color][/b] %s　[b]HPS[/b] %s（有效治疗%s / 护盾吸收%s）　累计击杀 %d\n装备 %d件　材料 %d个　装备收益 %.2f件/分钟\n自动出售 %d件 / 金币%d　自动分解 %d件 / 材料%d" % [snap.duration, compact_number(float(team.get("damage", 0))), compact_number(float(team.get("dps", 0))), compact_number(float(team.get("life_damage", 0))), compact_number(float(team.get("enemy_shield_damage", 0))), compact_number(float(team.get("healing", 0))), compact_number(float(team.get("hps", 0))), compact_number(float(team.get("effective_healing", 0))), compact_number(float(team.get("friendly_shield_absorbed", 0))), int(team.get("kills", 0)), int(snap.resources.equipment), int(snap.resources.materials), float(snap.get("equipment_per_minute", 0.0)), int(snap.resources.get("auto_sold_count", 0)), int(snap.resources.get("auto_sold_gold", 0)), int(snap.resources.get("auto_dismantled_count", 0)), int(snap.resources.get("auto_dismantled_material", 0))]
	var total_damage := maxf(1.0, float(team.get("damage", 0.0)))
	for index in range(ids.size()):
		var actor_id := ids[index]
		var row: Dictionary = snap.actors.get(actor_id, {})
		var controls: Dictionary = stats_actor_rows[actor_id]
		stats_rows_box.move_child(controls.root, index)
		var deployed: bool = actor_id in battle.progression.party
		controls.values.text = "[b]%s[/b] %s　[color=#FFB86B]伤害 %s｜DPS %s（生命%s / 敌盾%s）[/color]\n[color=#77E89A]治疗贡献 %s｜HPS %s（治疗%s / 护盾%s）[/color]　承伤 %s　施法 %d　击杀 %d" % [battle.actor_display_name(actor_id), "●上阵" if deployed else "○本次历史", compact_number(float(row.get("damage", 0))), compact_number(float(row.get("dps", 0))), compact_number(float(row.get("life_damage", 0))), compact_number(float(row.get("enemy_shield_damage", 0))), compact_number(float(row.get("healing", 0))), compact_number(float(row.get("hps", 0))), compact_number(float(row.get("effective_healing", 0))), compact_number(float(row.get("friendly_shield_absorbed", 0))), compact_number(float(row.get("taken", 0))), int(row.get("skills", 0)), int(row.get("kills", 0))]
		controls.values.tooltip_text = "伤害 %.0f｜DPS %.2f｜治疗 %.0f｜HPS %.2f｜承伤 %.0f" % [float(row.get("damage", 0)), float(row.get("dps", 0)), float(row.get("healing", 0)), float(row.get("hps", 0)), float(row.get("taken", 0))]
		controls.share.value = float(row.get("damage", 0.0)) * 100.0 / total_damage
		var sources: Dictionary = row.get("damage_sources", {})
		var heal_sources: Dictionary = row.get("heal_sources", {})
		controls.toggle.disabled = sources.is_empty() and heal_sources.is_empty()
		controls.toggle.text = "无技能明细" if controls.toggle.disabled else "收起贡献明细" if bool(stats_expanded.get(actor_id, false)) else "查看技能贡献"
		controls.detail.visible = bool(stats_expanded.get(actor_id, false)) and not controls.toggle.disabled
		if controls.detail.visible: controls.detail.text = _damage_source_detail(sources) + _healing_source_detail(heal_sources)

func _damage_source_detail(sources: Dictionary) -> String:
	if sources.is_empty(): return ""
	var ids: Array = sources.keys()
	ids.sort_custom(func(a, b): return float(sources[a].get("damage", 0.0)) > float(sources[b].get("damage", 0.0)))
	var lines: Array[String] = ["[color=#8A6840][b]伤害来源　　　　　　　　　伤害　　占比　次数　平均[/b][/color]"]
	for source_id in ids:
		var row: Dictionary = sources[source_id]
		lines.append("%s　[color=#D06A32]%s[/color]　%.1f%%　%d　%s" % [_damage_source_name(str(source_id)), compact_number(float(row.get("damage", 0.0))), float(row.get("percent", 0.0)), int(row.get("hits", 0)), compact_number(float(row.get("average", 0.0)))])
	return "\n".join(lines)

func _healing_source_detail(sources: Dictionary) -> String:
	if sources.is_empty(): return ""
	var ids: Array = sources.keys()
	ids.sort_custom(func(a, b): return float(sources[a].get("contribution", 0.0)) > float(sources[b].get("contribution", 0.0)))
	var lines: Array[String] = ["\n[color=#467A55][b]治疗来源　　　　　　　　　有效治疗　护盾吸收　总贡献　占比[/b][/color]"]
	for source_id in ids:
		var row: Dictionary = sources[source_id]
		lines.append("%s　%s　%s　[color=#4B9D68]%s[/color]　%.1f%%" % [_damage_source_name(str(source_id)), compact_number(float(row.get("healing", 0.0))), compact_number(float(row.get("shield", 0.0))), compact_number(float(row.get("contribution", 0.0))), float(row.get("percent", 0.0))])
	return "\n".join(lines)

func _damage_source_name(source_id: String) -> String:
	if source_id == "basic": return "普通攻击"
	if source_id == "basic_heal": return "普通攻击治疗"
	if source_id == "effect": return "其他战斗效果"
	if source_id.begins_with("summon:"):
		var summon_id := source_id.trim_prefix("summon:")
		return str(battle.actors.get(summon_id, {"name":summon_id}).get("name", summon_id)) + "·召唤攻击"
	var suffix := ""
	var base_id := source_id
	for spec in [[":burn", "·燃烧"], [":poison", "·中毒"], [":frost", "·冰霜"], [":hot", "·持续治疗"]]:
		if base_id.ends_with(spec[0]):
			base_id = base_id.substr(0, base_id.length() - str(spec[0]).length())
			suffix = spec[1]
			break
	if base_id.begins_with("passive:"):
		var passive_id := base_id.trim_prefix("passive:")
		return str(battle.passives_config.get(passive_id, {"name":passive_id}).get("name", passive_id)) + suffix
	if battle.skills.has(base_id): return str(battle.skills[base_id].get("name", base_id)) + suffix
	if battle.general_skills_config.has(base_id): return str(battle.general_skills_config[base_id].get("name", base_id)) + suffix
	return base_id + suffix

func compact_number(value: float) -> String:
	if absf(value) >= 1000000.0: return "%.2fM" % (value / 1000000.0)
	if absf(value) >= 1000.0: return "%.1fK" % (value / 1000.0)
	return "%.0f" % value

func build_settings() -> void:
	title.text = "设置 · 难度与安全重开"
	difficulty_preview = battle.progression.combat_difficulty
	var heading := Label.new(); heading.text = "战斗难度系数"; heading.add_theme_font_size_override("font_size", 21); content.add_child(heading)
	var preview_label := Label.new(); preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(preview_label)
	var slider := HSlider.new(); slider.min_value = 0.2; slider.max_value = 3.0; slider.step = 0.1; slider.value = difficulty_preview; slider.custom_minimum_size = Vector2(0, 34); content.add_child(slider)
	slider.value_changed.connect(func(value): difficulty_preview = snappedf(float(value), 0.1); _update_difficulty_preview(preview_label))
	var presets := GridContainer.new(); presets.columns = 5; content.add_child(presets)
	for spec in [["轻松", 0.5], ["标准", 1.0], ["挑战", 1.5], ["困难", 2.0], ["极限", 3.0]]:
		var button := Button.new(); button.text = "%s %.1f×" % [spec[0], spec[1]]; button.size_flags_horizontal = Control.SIZE_EXPAND_FILL; button.pressed.connect(_set_difficulty_preview.bind(float(spec[1]), slider, preview_label)); presets.add_child(button)
	var apply := Button.new(); apply.text = "应用难度（下一波开始生效）"; apply.pressed.connect(_apply_difficulty); V035ThemeScript.button(apply, "gold"); content.add_child(apply)
	var formula := Label.new(); formula.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; formula.text = "新版1.0× = 原4.4×难度，调整后下一波敌人生效。大世界敌人在非线性难度倍率后额外应用生命80%、防御80%；大秘境不应用该削弱。玩家属性与奖励不变。"; content.add_child(formula)
	content.add_child(HSeparator.new())
	var auto_heading := Label.new(); auto_heading.text = "自动装备处理（仅处理开启后新掉落的普通装备）"; auto_heading.add_theme_font_size_override("font_size", 21); content.add_child(auto_heading)
	var auto_settings: Dictionary = battle.progression.auto_equipment_settings
	var sell_row := HBoxContainer.new(); content.add_child(sell_row)
	var sell_toggle := CheckButton.new(); sell_toggle.text = "自动出售装备"; sell_toggle.button_pressed = bool(auto_settings.get("sell_enabled", false)); sell_toggle.toggled.connect(_set_auto_equipment_setting.bind("sell_enabled")); sell_row.add_child(sell_toggle)
	var sell_quality := OptionButton.new(); _populate_auto_quality_select(sell_quality, str(auto_settings.get("sell_max_quality", "white"))); sell_quality.item_selected.connect(_auto_quality_selected.bind(sell_quality, "sell_max_quality")); sell_row.add_child(sell_quality)
	var dismantle_row := HBoxContainer.new(); content.add_child(dismantle_row)
	var dismantle_toggle := CheckButton.new(); dismantle_toggle.text = "自动分解装备"; dismantle_toggle.button_pressed = bool(auto_settings.get("dismantle_enabled", false)); dismantle_toggle.toggled.connect(_set_auto_equipment_setting.bind("dismantle_enabled")); dismantle_row.add_child(dismantle_toggle)
	var dismantle_quality := OptionButton.new(); _populate_auto_quality_select(dismantle_quality, str(auto_settings.get("dismantle_max_quality", "white"))); dismantle_quality.item_selected.connect(_auto_quality_selected.bind(dismantle_quality, "dismantle_max_quality")); dismantle_row.add_child(dismantle_quality)
	var priority_row := HBoxContainer.new(); content.add_child(priority_row)
	var priority_label := Label.new(); priority_label.text = "同时符合时："; priority_row.add_child(priority_label)
	var priority := OptionButton.new(); priority.add_item("优先分解"); priority.set_item_metadata(0, "dismantle"); priority.add_item("优先出售"); priority.set_item_metadata(1, "sell"); priority.selected = 0 if str(auto_settings.get("priority", "dismantle")) == "dismantle" else 1; priority.item_selected.connect(_auto_priority_selected.bind(priority)); priority_row.add_child(priority)
	var auto_preview := Label.new(); auto_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; auto_preview.text = _auto_equipment_preview(); auto_preview.add_theme_color_override("font_color", Color("#FFD27A")); content.add_child(auto_preview)
	var auto_hint := Label.new(); auto_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; auto_hint.text = "已穿戴、已锁定、旧背包装备、商店购买、首通/特殊奖励均不自动处理。符合规则的新掉落会在背包容量检查前直接换成金币或重铸材料，且每件只结算一次。"; content.add_child(auto_hint)
	content.add_child(HSeparator.new())
	var guide := Button.new(); guide.text = "重新查看新手引导（不重置存档）"; guide.pressed.connect(func(): battle.progression.restart_guide(); settings_feedback = "新手引导已重新开启。"; refresh()); content.add_child(guide)
	var reset := Button.new(); reset.text = "重新开始游戏（先自动备份）"; reset.tooltip_text = "备份并逐字节校验成功后才会重置全部进度"; reset.pressed.connect(func(): reset_dialog.popup_centered()); V035ThemeScript.button(reset, "blue"); content.add_child(reset)
	var feedback := Label.new(); feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; feedback.text = settings_feedback if not settings_feedback.is_empty() else "重新开始后：仅刘备Lv.1、虎符150、金币0、主线第1关、默认难度1.0×，并恢复完整新手引导。"; feedback.add_theme_color_override("font_color", Color("#FFD27A")); content.add_child(feedback)
	_update_difficulty_preview(preview_label)

func _populate_auto_quality_select(select: OptionButton, selected_quality: String) -> void:
	var labels := {"white":"白色及以下", "green":"绿色及以下", "blue":"蓝色及以下", "purple":"紫色及以下", "orange":"橙色及以下"}
	for quality in ["white", "green", "blue", "purple", "orange"]:
		select.add_item(labels[quality])
		select.set_item_metadata(select.item_count - 1, quality)
		if quality == selected_quality:
			select.selected = select.item_count - 1

func _auto_quality_selected(index: int, select: OptionButton, key: String) -> void:
	var quality := str(select.get_item_metadata(index))
	if quality in ["purple", "orange"]:
		pending_auto_equipment_setting = {"key":key, "value":quality}
		auto_equipment_warning_dialog.dialog_text = "选择%s可能让今后新掉落的稀有装备被不可撤销地自动处理。\n\n已穿戴、锁定、旧装备及特殊奖励仍会受到保护。" % ("紫色及以下" if quality == "purple" else "橙色及以下")
		auto_equipment_warning_dialog.popup_centered()
		return
	_set_auto_equipment_setting(quality, key)

func _auto_priority_selected(index: int, select: OptionButton) -> void:
	_set_auto_equipment_setting(str(select.get_item_metadata(index)), "priority")

func _set_auto_equipment_setting(value, key: String) -> void:
	if battle.progression.set_auto_equipment_setting(key, value):
		settings_feedback = "自动装备处理设置已保存，只对之后获得的新普通掉落生效。"
		refresh()

func _confirm_auto_equipment_setting() -> void:
	if pending_auto_equipment_setting.is_empty():
		return
	_set_auto_equipment_setting(pending_auto_equipment_setting.value, str(pending_auto_equipment_setting.key))
	pending_auto_equipment_setting.clear()

func _cancel_auto_equipment_setting() -> void:
	pending_auto_equipment_setting.clear()
	refresh()

func _auto_equipment_preview() -> String:
	var settings: Dictionary = battle.progression.auto_equipment_settings
	var ranks := {"white":0, "green":1, "blue":2, "purple":3, "orange":4}
	var labels := {"white":"白", "green":"绿", "blue":"蓝", "purple":"紫", "orange":"橙"}
	var outcomes: Array[String] = []
	for quality in ["white", "green", "blue", "purple", "orange"]:
		var sell_match := bool(settings.get("sell_enabled", false)) and int(ranks[quality]) <= int(ranks.get(str(settings.get("sell_max_quality", "white")), 0))
		var dismantle_match := bool(settings.get("dismantle_enabled", false)) and int(ranks[quality]) <= int(ranks.get(str(settings.get("dismantle_max_quality", "white")), 0))
		var result := "保留"
		if sell_match or dismantle_match:
			result = "分解" if dismantle_match and (not sell_match or str(settings.get("priority", "dismantle")) == "dismantle") else "出售"
		outcomes.append("%s装：%s" % [labels[quality], result])
	return "处理预览｜" + "　".join(outcomes)

func _update_difficulty_preview(label: Label) -> void:
	var profile: Dictionary = battle.custom_difficulty_profile(difficulty_preview)
	label.text = "新版难度 %.1f×（当前已应用 %.3f×）｜等价旧版 %.2f×\n难度曲线：生命 %.2f×、攻击 %.2f×、防御 %.2f×\n大世界实际：生命 %.2f×、攻击 %.2f×、防御 %.2f×；大秘境保留独立层数曲线，不应用80%%削弱" % [difficulty_preview, battle.progression.combat_difficulty, profile.equivalent_old_coefficient, profile.health, profile.attack, profile.defense, profile.world_health, profile.attack, profile.world_defense]

func _set_difficulty_preview(value: float, slider: HSlider, label: Label) -> void:
	difficulty_preview = value
	slider.value = value
	_update_difficulty_preview(label)

func _apply_difficulty() -> void:
	var applied: float = battle.progression.set_combat_difficulty(difficulty_preview)
	settings_feedback = "战斗难度已保存为 %.1f×，当前敌人不变，下一波/Boss/秘境/奇遇开始生效。" % applied
	battle.log_message.emit(settings_feedback)
	refresh()

func _confirm_safe_reset() -> void:
	var result: Dictionary = battle.safe_restart_game()
	if bool(result.get("ok", false)):
		settings_feedback = "备份校验成功：%s。正在载入全新冒险。" % str(result.get("backup_path", ""))
		call_deferred("_reload_after_reset")
	else:
		settings_feedback = "重开失败，原存档保持不变：" + str(result.get("error", "未知错误"))
		if bool(result.get("reload_required", false)): call_deferred("_reload_after_reset")
		else: refresh()

func _reload_after_reset() -> void:
	get_tree().reload_current_scene()

func _clear_combat_stats() -> void:
	battle.reset_combat_stats()
	update_stats_view()

func exchange_actor(index: int, list: ItemList) -> void:
	selected_party_actor = str(list.get_item_metadata(index))
	_recruit_selected_actor()

func assign_selected_party(index: int) -> void:
	if battle.assign_party_member(index, selected_party_actor):
		recruit_feedback = "%s已放入位置%d，战场已立即更新。" % [battle.actor_display_name(selected_party_actor), index + 1]
		battle.rebuild_party()
		refresh()

func clear_party_slot(index: int) -> void:
	if battle.assign_party_member(index, ""):
		recruit_feedback = "位置%d已清空。" % (index + 1)
		battle.rebuild_party()
		refresh()

func change_party(index: int, select_index: int, select: OptionButton) -> void:
	if battle.assign_party_member(index, select.get_item_metadata(select_index)):
		battle.rebuild_party()
		refresh()

func update_strategy(value: float, key: String) -> void:
	battle.progression.strategy_presets[battle.progression.active_strategy][key] = int(value) if key == "enemy_count" else value
	battle.progression.save_to_disk()

func add_separator(text_value: String) -> void:
	var label := Label.new(); label.text = text_value; label.add_theme_font_size_override("font_size", 18); content.add_child(label)

func material_name(id: String) -> String:
	return {"three_kingdoms_token":"虎符", "pokemon_token":"精灵结晶", "dragon_blood_crystal":"龙血结晶", "jianghu_token":"江湖令", "azeroth_token":"艾泽拉斯徽记", "wuxia_token":"侠义令", "qin_moon_token":"苍龙令", "ninja_scroll":"忍界卷轴", "huangyi_token":"战神令", "fengyun_token":"风云令", "salvage_dust":"重铸材料"}.get(id, id)
