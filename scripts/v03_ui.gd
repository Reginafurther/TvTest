class_name V03UI
extends CanvasLayer

var battle
var panel: PanelContainer
var content: VBoxContainer
var title: Label
var current_view := ""
var selected_item_id := ""
var selected_affix := 0
var confirm_dialog: ConfirmationDialog
var pending_dismantle := ""

func setup(owner_battle) -> void:
	battle = owner_battle
	layer = 20
	build_toolbar()
	build_panel()
	battle.progression_changed.connect(refresh_if_open)
	battle.inventory.inventory_changed.connect(refresh_if_open)

func build_toolbar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 54)
	bar.add_theme_constant_override("separation", 5)
	add_child(bar)
	for spec in [["世界地图", "world"], ["招募编队", "recruit"], ["分解重铸", "craft"], ["战斗策略", "strategy"], ["战斗统计", "stats"]]:
		var button := Button.new()
		button.text = spec[0]
		button.pressed.connect(open_view.bind(spec[1]))
		bar.add_child(button)

func build_panel() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(120, 105)
	panel.size = Vector2(860, 500)
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
	content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "确认分解高品质装备"
	confirm_dialog.confirmed.connect(confirm_dismantle)
	add_child(confirm_dialog)

func open_view(view: String) -> void:
	current_view = view
	panel.visible = true
	battle.is_paused = true
	battle.battle_state_changed.emit("功能界面中")
	refresh()

func close_panel() -> void:
	panel.visible = false
	battle.is_paused = false
	battle.battle_state_changed.emit("自动战斗中")

func clear_content() -> void:
	for child in content.get_children():
		child.queue_free()

func refresh_if_open() -> void:
	if panel.visible:
		refresh()

func refresh() -> void:
	clear_content()
	match current_view:
		"world": build_world()
		"recruit": build_recruit()
		"craft": build_craft()
		"strategy": build_strategy()
		"stats": build_stats()

func build_world() -> void:
	title.text = "双世界冒险"
	var info := Label.new()
	info.text = "当前：%s　队伍与装备会随地图保留" % battle.worlds_config.maps[battle.current_map_id].name
	content.add_child(info)
	for map_id in battle.worlds_config.maps:
		var data: Dictionary = battle.worlds_config.maps[map_id]
		var button := Button.new()
		button.text = "前往 %s（Lv.%d） · 掉落%s" % [data.name, data.level, data.material_name]
		button.disabled = map_id == battle.current_map_id and battle.active_boss_id.is_empty()
		button.pressed.connect(func(): battle.switch_map(map_id); close_panel())
		content.add_child(button)
	add_separator("传奇挑战")
	for boss_id in battle.worlds_config.bosses:
		var data: Dictionary = battle.worlds_config.bosses[boss_id]
		var button := Button.new()
		button.text = "%s　%s" % [data.name, "已首胜，可重复挑战" if battle.progression.boss_first_clear[boss_id] else "首胜解锁角色"]
		button.pressed.connect(func(): battle.start_boss(boss_id); close_panel())
		content.add_child(button)

func build_recruit() -> void:
	title.text = "角色招募与四人编队"
	var p = battle.progression
	var info := Label.new()
	info.text = "招募令：%d　虎符：%d　精灵结晶：%d　已招募：%d/10" % [p.recruit_tokens, p.materials.three_kingdoms_token, p.materials.pokemon_token, p.roster.size()]
	content.add_child(info)
	var recruit := Button.new()
	recruit.text = "使用招募令随机招募非传奇角色"
	recruit.disabled = p.recruit_tokens <= 0
	recruit.pressed.connect(use_recruit_token)
	content.add_child(recruit)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(0, 190)
	for actor_id in battle.worlds_config.recruitment.costs:
		var cost: Array = battle.worlds_config.recruitment.costs[actor_id]
		var owned: bool = actor_id in p.roster
		var idx := list.add_item("%s · %s" % [battle.actors[actor_id].name, "已招募" if owned else "%s ×%d" % [material_name(cost[0]), cost[1]]])
		list.set_item_metadata(idx, actor_id)
	list.item_activated.connect(exchange_actor.bind(list))
	content.add_child(list)
	var hint := Label.new()
	hint.text = "双击未招募角色可定向兑换。编队变更会立即重建战场。"
	content.add_child(hint)
	var row := HBoxContainer.new()
	content.add_child(row)
	for i in range(4):
		var select := OptionButton.new()
		select.custom_minimum_size = Vector2(190, 36)
		for actor_id in p.roster:
			select.add_item("位置%d · %s" % [i + 1, battle.actors[actor_id].name])
			select.set_item_metadata(select.item_count - 1, actor_id)
			if actor_id == p.party[i]: select.select(select.item_count - 1)
		select.item_selected.connect(change_party.bind(i, select))
		row.add_child(select)

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
	title.text = "自动战斗策略"
	var p = battle.progression
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
		var label := Label.new(); label.text = spec[0]; label.custom_minimum_size = Vector2(220, 30); row.add_child(label)
		var spin := SpinBox.new(); spin.min_value = 1 if spec[1] == "enemy_count" else 0.05; spin.max_value = 8 if spec[1] == "enemy_count" else 1.0; spin.step = 1 if spec[1] == "enemy_count" else 0.05; spin.value = data[spec[1]]; spin.value_changed.connect(update_strategy.bind(spec[1])); row.add_child(spin)
	var help := Label.new(); help.text = "条件不满足时跳过技能并普通攻击。两套预设会自动保存。"; content.add_child(help)

func build_stats() -> void:
	title.text = "实时战斗统计"
	var snap: Dictionary = battle.stats_snapshot()
	var text := RichTextLabel.new(); text.bbcode_enabled = true; text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = "统计时长 %.1f 秒　装备 %d　材料 %d　资源/分钟 %.1f\n\n" % [snap.duration, snap.resources.equipment, snap.resources.materials, snap.resources_per_minute]
	for actor_id in snap.actors:
		var row: Dictionary = snap.actors[actor_id]
		text.append_text("[b]%s[/b]　伤害 %.0f　DPS %.1f　普攻 %.0f　技能 %.0f　特效 %.0f　治疗 %.0f　承伤 %.0f　技能%d　击杀%d\n" % [battle.actors.get(actor_id, {"name": actor_id}).name, row.damage, row.dps, row.basic, row.skill, row.effect, row.healing, row.taken, row.skills, row.kills])
	content.add_child(text)

func use_recruit_token() -> void:
	var id: String = battle.progression.use_recruit_token(battle.worlds_config.recruitment.starter_pool, battle.equipment_generator.rng)
	if not id.is_empty(): battle.log_message.emit("招募成功：%s" % battle.actors[id].name)
	refresh()

func exchange_actor(index: int, list: ItemList) -> void:
	var id: String = list.get_item_metadata(index)
	var cost: Array = battle.worlds_config.recruitment.costs[id]
	if battle.progression.exchange_actor(id, cost[0], int(cost[1])): battle.log_message.emit("定向招募：%s" % battle.actors[id].name)
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
