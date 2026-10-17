extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")
const V03UIScript = preload("res://scripts/v03_ui.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	var character_ui = CharacterUIScript.new()
	root.add_child(character_ui)
	character_ui.setup(battle)
	var feature_ui = V03UIScript.new()
	root.add_child(feature_ui)
	feature_ui.setup(battle)
	var actor_count: int = battle.progression.actor_levels.size()
	await _validate_world_navigation(feature_ui, battle)
	await process_frame
	await process_frame
	_validate_character_grouping(character_ui, battle)
	battle.clear_combatants()
	character_ui.queue_free()
	feature_ui.queue_free()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V144_WORLD_CHARACTER_UI_PASS worlds=10 nav_buttons=11 roster_sorts=4 actors=%d dynamic=true" % actor_count)
		quit(0)
		return
	for failure in failures:
		push_error("V144_WORLD_CHARACTER_UI_FAIL: " + failure)
	quit(1)

func _validate_world_navigation(feature_ui, battle) -> void:
	feature_ui.open_view("world")
	var tabs: Array[Node] = feature_ui.content.find_children("WorldTabs", "HBoxContainer", true, false)
	var scrolls: Array[Node] = feature_ui.content.find_children("WorldNavigation", "ScrollContainer", true, false)
	var rows: Array[Node] = feature_ui.content.find_children("WorldNavigationRow", "HBoxContainer", true, false)
	if tabs.size() != 1 or scrolls.size() != 1 or rows.size() != 1:
		failures.append("世界导航单行滚动结构缺失")
		return
	var world_names: Array[String] = []
	for button in tabs[0].get_children():
		world_names.append(str(button.text).replace(" 🔒", ""))
	var expected := ["全部", "三国", "宝可梦", "龙族", "逆水寒", "魔兽世界", "金庸", "秦时明月", "火影忍者", "黄易", "风云"]
	if world_names != expected: failures.append("世界按钮顺序或内容错误：%s" % str(world_names))
	if scrolls[0].horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED or scrolls[0].vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		failures.append("世界导航不是纯横向滚动")
	if rows[0].find_child("WorldNavigationPrevious", true, false) == null or rows[0].find_child("WorldNavigationNext", true, false) == null:
		failures.append("世界导航左右箭头缺失")
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	feature_ui._world_navigation_input(wheel, scrolls[0])
	if scrolls[0].scroll_horizontal <= 0: failures.append("鼠标滚轮不能横向滚动世界导航")
	feature_ui._select_world_tab("风云")
	await process_frame
	await process_frame
	if feature_ui.selected_world_tab != "风云": failures.append("风云世界切换失败")
	var fengyun_stages: Array[Node] = feature_ui.content.find_children("WorldStageScroll", "ScrollContainer", true, false)
	if fengyun_stages.size() != 1 or fengyun_stages[0].find_children("*", "Button", true, false).size() != 10:
		failures.append("风云分类没有只显示10关")
	var refreshed_scrolls: Array[Node] = feature_ui.content.find_children("WorldNavigation", "ScrollContainer", true, false)
	if refreshed_scrolls.size() == 1 and refreshed_scrolls[0].scroll_horizontal <= 0:
		failures.append("选择末端世界后没有自动滚动至可见位置")
	feature_ui._select_world_tab("全部")
	await process_frame
	var all_stages: Array[Node] = feature_ui.content.find_children("WorldStageScroll", "ScrollContainer", true, false)
	if all_stages.size() != 1 or all_stages[0].find_children("*", "Button", true, false).size() != battle.worlds_config.maps.size():
		failures.append("全部入口没有展示现有全部主线关卡")

func _validate_character_grouping(character_ui, battle) -> void:
	if character_ui.sort_select.item_count != 4 or character_ui.sort_select.get_item_text(3) != "按世界":
		failures.append("角色排序下拉框缺少按世界")
		return
	character_ui.selected_actor = str(battle.progression.roster[0])
	var selected_before: String = character_ui.selected_actor
	for mode in range(3):
		character_ui.sort_select.select(mode)
		character_ui.refresh_roster()
		if character_ui.actor_list.item_count != battle.progression.roster.size():
			failures.append("原排序模式%d不再只显示已获得角色" % mode)
		if character_ui.selected_actor != selected_before:
			failures.append("切换原排序模式重置了选中角色")
	character_ui.sort_select.select(3)
	character_ui.refresh_roster()
	var playable_ids: Array = character_ui._playable_actor_ids()
	var ordered_worlds: Array = character_ui._ordered_actor_worlds(playable_ids)
	if character_ui.actor_list.item_count != playable_ids.size() + ordered_worlds.size():
		failures.append("按世界模式没有显示全部角色及分组标题")
	var seen_actor_ids: Array[String] = []
	var headers: Array[String] = []
	var has_unowned := false
	for index in range(character_ui.actor_list.item_count):
		var actor_id := str(character_ui.actor_list.get_item_metadata(index))
		if actor_id.is_empty():
			headers.append(character_ui.actor_list.get_item_text(index))
			if character_ui.actor_list.is_item_selectable(index): failures.append("世界分组标题可被选中")
		else:
			seen_actor_ids.append(actor_id)
			if actor_id not in battle.progression.roster:
				has_unowned = true
				if not character_ui.actor_list.is_item_disabled(index): failures.append("未获得角色没有保持禁用状态")
	if seen_actor_ids.size() != playable_ids.size(): failures.append("按世界模式发生角色遗漏或重复")
	if not has_unowned: failures.append("按世界模式没有保留未获得角色")
	if headers.is_empty() or not headers[0].contains("三国（") or not headers[0].contains("/10"):
		failures.append("世界标题或动态人数格式错误")
	if character_ui.actor_list.item_count > 1 and str(character_ui.actor_list.get_item_metadata(1)) != str(battle.progression.party[0]):
		failures.append("世界分组内没有优先显示上阵角色")
	if character_ui.selected_actor != selected_before:
		failures.append("切换按世界后重置了选中角色")
	# Add a synthetic future world and actor to prove both UIs derive groups from data.
	battle.actors.future_ui_actor = {"name":"未来测试角色", "world":"未来世界", "role":"测试", "max_hp":1, "attack":1, "defense":1}
	battle.progression.actor_levels.future_ui_actor = battle.progression.team_level
	battle.worlds_config.maps.future_ui_stage = {"world":"未来世界", "name":"未来关卡", "global_stage":101, "difficulty_level":101}
	character_ui.refresh_roster()
	var future_found := false
	for index in range(character_ui.actor_list.item_count):
		if str(character_ui.actor_list.get_item_metadata(index)) == "future_ui_actor": future_found = true
	if not future_found: failures.append("新增世界角色没有自动进入世界分组")
