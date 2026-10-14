class_name CampUI
extends CanvasLayer

const V035ThemeScript = preload("res://scripts/v035_theme.gd")

signal actor_requested(actor_id: String)

class FurnitureDragButton extends Button:
	var furniture_id := ""
	func _get_drag_data(_at_position: Vector2):
		if disabled: return null
		var preview := Label.new(); preview.text = text; preview.modulate = Color(1, 1, 1, 0.85); set_drag_preview(preview)
		return {"furniture_id":furniture_id}

class CampBoard extends Control:
	signal actor_clicked(actor_id: String)
	var manager
	var dragging_placement := ""
	var drag_start := Vector2i.ZERO
	const CELL := 54
	const COLS := 12
	const ROWS := 8
	func _ready() -> void:
		custom_minimum_size = Vector2(CELL * COLS, CELL * ROWS)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#7FA36B"))
		for x in range(COLS + 1): draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ROWS * CELL), Color(1,1,1,0.13), 1)
		for y in range(ROWS + 1): draw_line(Vector2(0, y * CELL), Vector2(COLS * CELL, y * CELL), Color(1,1,1,0.13), 1)
		if manager == null: return
		for row in manager.battle.progression.camp_layout:
			var data: Dictionary = manager.config.furniture.get(str(row.furniture_id), {})
			var dimensions: Array = data.get("size", [1,1])
			var rect := Rect2(float(row.x) * CELL + 3, float(row.y) * CELL + 3, float(dimensions[0]) * CELL - 6, float(dimensions[1]) * CELL - 6)
			draw_rect(rect, Color("#F0D49A") if str(row.placement_id) != dragging_placement else Color("#FFE67A"), true)
			draw_rect(rect, Color("#704F32"), false, 2)
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(7, 24), str(data.get("name", row.furniture_id)), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 12, 15, Color("#3F3026"))
		var roster: Array = manager.battle.progression.roster
		for index in range(mini(roster.size(), 8)):
			var actor_id := str(roster[index]); var x := 28.0 + index * 72.0
			draw_circle(Vector2(x, ROWS * CELL - 25), 17, Color(manager.battle.actors.get(actor_id, {}).get("color", "FFFFFF")))
			draw_string(ThemeDB.fallback_font, Vector2(x - 20, ROWS * CELL - 2), str(manager.battle.actors.get(actor_id, {}).get("name", actor_id)), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color("#24332B"))
	func _can_drop_data(_at_position: Vector2, data) -> bool:
		return manager != null and typeof(data) == TYPE_DICTIONARY and data.has("furniture_id")
	func _drop_data(at_position: Vector2, data) -> void:
		manager.place_furniture(str(data.furniture_id), Vector2i(floori(at_position.x / CELL), floori(at_position.y / CELL)))
		queue_redraw()
	func _gui_input(event: InputEvent) -> void:
		if manager == null: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var cell := Vector2i(floori(event.position.x / CELL), floori(event.position.y / CELL))
				for row in manager.battle.progression.camp_layout:
					var dimensions: Array = manager.config.furniture.get(str(row.furniture_id), {}).get("size", [1,1])
					if Rect2i(Vector2i(int(row.x), int(row.y)), Vector2i(int(dimensions[0]), int(dimensions[1]))).has_point(cell):
						dragging_placement = str(row.placement_id); drag_start = cell; queue_redraw(); accept_event(); return
				if event.position.y >= ROWS * CELL - 52:
					var actor_index := clampi(roundi((event.position.x - 28.0) / 72.0), 0, manager.battle.progression.roster.size() - 1)
					if actor_index >= 0 and actor_index < manager.battle.progression.roster.size(): actor_clicked.emit(str(manager.battle.progression.roster[actor_index])); accept_event(); return
			elif not dragging_placement.is_empty():
				var target := Vector2i(floori(event.position.x / CELL), floori(event.position.y / CELL))
				manager.move_furniture(dragging_placement, target)
				dragging_placement = ""; queue_redraw(); accept_event()
	func remove_selected() -> bool:
		if dragging_placement.is_empty(): return false
		var result: bool = manager.return_furniture(dragging_placement); dragging_placement = ""; queue_redraw(); return result

var battle
var panel: PanelContainer
var warehouse: VBoxContainer
var board: CampBoard
var collection_text: RichTextLabel
var achievement_box: VBoxContainer
var feedback: Label

func setup(owner_battle) -> void:
	battle = owner_battle
	layer = 45
	build_ui()
	battle.adventure.changed.connect(refresh_all)
	panel.visible = false

func build_ui() -> void:
	panel = PanelContainer.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#E7D7B5"), Color("#9C6A3F"), 16, 8)); add_child(panel)
	var root := VBoxContainer.new(); panel.add_child(root)
	var header := HBoxContainer.new(); root.add_child(header)
	var title := Label.new(); title.text = "冒险团营地 · 装修与收藏"; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; V035ThemeScript.label(title, 25, Color("#493520")); header.add_child(title)
	feedback = Label.new(); feedback.custom_minimum_size = Vector2(420, 32); feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; header.add_child(feedback)
	var close := Button.new(); close.text = "返回战斗"; close.pressed.connect(close_panel); header.add_child(close)
	var columns := HBoxContainer.new(); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation", 12); root.add_child(columns)
	var left := VBoxContainer.new(); left.custom_minimum_size = Vector2(260, 0); columns.add_child(left)
	var left_title := Label.new(); left_title.text = "家具仓库（拖到营地）"; left.add_child(left_title)
	var warehouse_scroll := ScrollContainer.new(); warehouse_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; left.add_child(warehouse_scroll)
	warehouse = VBoxContainer.new(); warehouse.size_flags_horizontal = Control.SIZE_EXPAND_FILL; warehouse_scroll.add_child(warehouse)
	var return_button := Button.new(); return_button.text = "收回当前选中家具"; return_button.pressed.connect(func(): feedback.text = "家具已收回仓库。" if board.remove_selected() else "请先在营地点击一个家具。"; refresh_all()); left.add_child(return_button)
	var center := VBoxContainer.new(); center.size_flags_horizontal = Control.SIZE_EXPAND_FILL; columns.add_child(center)
	var hint := Label.new(); hint.text = "12×8吸附网格｜拖入摆放｜点击后拖动可换位｜边界与重叠会被阻止"; center.add_child(hint)
	board = CampBoard.new(); board.manager = battle.adventure; board.size_flags_horizontal = Control.SIZE_EXPAND_FILL; board.size_flags_vertical = Control.SIZE_EXPAND_FILL; center.add_child(board)
	board.actor_clicked.connect(func(actor_id): actor_requested.emit(actor_id))
	var right := TabContainer.new(); right.custom_minimum_size = Vector2(330, 0); columns.add_child(right)
	collection_text = RichTextLabel.new(); collection_text.name = "收藏与角色"; collection_text.bbcode_enabled = true; right.add_child(collection_text)
	var achievement_scroll := ScrollContainer.new(); achievement_scroll.name = "成就"; achievement_box = VBoxContainer.new(); achievement_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; achievement_scroll.add_child(achievement_box); right.add_child(achievement_scroll)

func open() -> void:
	panel.visible = true; battle.is_paused = true; battle.battle_state_changed.emit("营地装修中"); refresh_all()

func close_panel() -> void:
	panel.visible = false; battle.is_paused = false; battle.battle_state_changed.emit("自动战斗中")

func refresh_all() -> void:
	if panel == null: return
	for child in warehouse.get_children(): child.queue_free()
	for id in battle.adventure.config.furniture:
		var available: int = battle.adventure.furniture_available(str(id)); var owned := int(battle.progression.camp_inventory.get(id, 0))
		if owned <= 0: continue
		var button := FurnitureDragButton.new(); button.furniture_id = str(id); button.text = "%s  可摆%d / 拥有%d" % [battle.adventure.config.furniture[id].name, available, owned]; button.disabled = available <= 0; warehouse.add_child(button)
	board.queue_redraw()
	var lines: Array[String] = ["[b]已招募角色陈列[/b]"]
	for actor_id in battle.progression.roster:
		lines.append("• %s　Lv.%d　%s" % [battle.actors.get(actor_id, {}).get("name", actor_id), battle.progression.actor_level(str(actor_id)), battle.actors.get(actor_id, {}).get("role", "冒险者")])
	lines.append("\n[b]战利品收藏[/b]")
	if battle.progression.collectibles.is_empty(): lines.append("尚未获得；秘境、奇遇和成就会掉落收藏品。")
	for id in battle.progression.collectibles:
		var row = battle.progression.collectibles[id]; lines.append("• %s ×%d" % [row.get("name", id), int(row.get("count", 1))])
	collection_text.text = "\n".join(lines)
	for child in achievement_box.get_children(): child.queue_free()
	for id in battle.adventure.config.achievements:
		var data: Dictionary = battle.adventure.config.achievements[id]; var claimed := bool(battle.progression.achievements.get(id, {}).get("claimed", false)); var ready: bool = battle.adventure.achievement_ready(str(id))
		var button := Button.new(); button.text = "%s　%s" % [data.name, "已领取" if claimed else "领取奖励" if ready else "未达成"]; button.disabled = claimed or not ready; button.pressed.connect(_claim_achievement.bind(str(id))); achievement_box.add_child(button)

func _claim_achievement(id: String) -> void:
	feedback.text = "成就奖励已领取。" if battle.adventure.claim_achievement(id) else "尚未达成或已经领取。"; refresh_all()
