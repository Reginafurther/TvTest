class_name TutorialUI
extends CanvasLayer

const V035ThemeScript = preload("res://scripts/v035_theme.gd")

const STEPS := [
	["1/6 材料招募", "你有150枚虎符。点击“招募”，双击一名三国输出角色完成定向招募。", "招募", "recruit"],
	["2/6 角色上阵", "在招募页选中刚获得的角色，点击任一空位置的“上阵/替换”。", "招募", "recruit"],
	["3/6 自动战斗", "有输出角色上阵后第一关自动开战。观察职业站位与自动攻击。", "查看地图", ""],
	["4/6 获得装备", "怪物会随机掉落装备并自动拾取，等待掉落后打开角色页背包。", "背包", "inventory"],
	["5/6 穿戴装备", "比较真实属性收益，再为任意已获得角色穿戴装备。", "背包", "inventory"],
	["6/6 组建四人队", "继续用剩余虎符招募并把四个位置补齐，然后挑战主线。", "招募", "recruit"]
]

var battle
var inventory_ui
var feature_ui
var panel: PanelContainer
var title: Label
var description: Label
var action_button: Button
var replay_next: Button
var objective: Label
var initial_party: Array = []
var initial_kills := 0
var initial_items := 0

func setup(owner_battle, backpack, features) -> void:
	battle = owner_battle
	inventory_ui = backpack
	feature_ui = features
	initial_party = battle.progression.party.duplicate()
	initial_kills = battle.kills
	initial_items = battle.inventory.items.size()
	layer = 30
	build_ui()
	battle.progression.changed.connect(refresh)
	battle.inventory.inventory_changed.connect(refresh)
	battle.world_changed.connect(func(_id): refresh())
	refresh()

func build_ui() -> void:
	panel = PanelContainer.new()
	panel.position = Vector2(198, 72)
	panel.size = Vector2(400, 110)
	panel.add_theme_stylebox_override("panel", V035ThemeScript.box(Color("#FFF4DB"), Color("#CB9750"), 14, 8))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var text_column := VBoxContainer.new()
	text_column.custom_minimum_size = Vector2(265, 90)
	row.add_child(text_column)
	title = Label.new()
	V035ThemeScript.label(title, 18, Color("#493721"))
	text_column.add_child(title)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(260, 60)
	V035ThemeScript.label(description, 14, Color("#5E4A36"))
	text_column.add_child(description)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size = Vector2(105, 90)
	actions.add_theme_constant_override("separation", 3)
	row.add_child(actions)
	action_button = Button.new()
	V035ThemeScript.button(action_button, "gold")
	action_button.add_theme_font_size_override("font_size", 14)
	action_button.custom_minimum_size = Vector2(102, 37)
	action_button.pressed.connect(_go_to_action)
	actions.add_child(action_button)
	replay_next = Button.new()
	replay_next.text = "下一步"
	V035ThemeScript.button(replay_next, "green")
	replay_next.add_theme_font_size_override("font_size", 12)
	replay_next.custom_minimum_size = Vector2(102, 24)
	replay_next.pressed.connect(func(): battle.progression.set_guide_step(battle.progression.guide_step + 1))
	actions.add_child(replay_next)
	var skip := Button.new()
	skip.text = "跳过"
	V035ThemeScript.button(skip, "cream")
	skip.add_theme_font_size_override("font_size", 12)
	skip.custom_minimum_size = Vector2(102, 24)
	skip.pressed.connect(func(): battle.progression.skip_guide())
	actions.add_child(skip)
	objective = Label.new()
	objective.visible = false
	text_column.add_child(objective)

func apply_layout(_viewport_size: Vector2, factor: float, offset_x: float, header_h: float) -> void:
	panel.position = Vector2(offset_x + 198 * factor, header_h + 14 * factor)
	panel.scale = Vector2.ONE * factor

func _process(_delta: float) -> void:
	if not battle.progression.guide_finished:
		advance_from_state()

func advance_from_state() -> void:
	var p = battle.progression
	if p.guide_replay: return
	var done := false
	match p.guide_step:
		0: done = p.roster.size() >= 2
		1: done = battle.has_damage_dealer_in_party()
		2: done = battle.kills > initial_kills
		3: done = battle.inventory.items.size() > initial_items
		4:
			for actor_id in p.roster:
				for item_id in battle.inventory.equipped.get(actor_id, {}).values():
					if not str(item_id).is_empty(): done = true
		5: done = p.active_party().size() == 4
	if done:
		p.set_guide_step(p.guide_step + 1)
		if p.guide_step == 3: initial_items = battle.inventory.items.size()
		refresh()

func refresh() -> void:
	if panel == null: return
	var p = battle.progression
	panel.visible = not p.guide_finished
	if p.guide_finished: return
	var step: int = clampi(p.guide_step, 0, 5)
	title.text = STEPS[step][0]
	description.text = STEPS[step][1]
	action_button.text = "前往" + STEPS[step][2]
	replay_next.visible = p.guide_replay
	objective.text = "回顾模式 · 点下一步" if p.guide_replay else ("正在进行 · 不会阻止战斗" if not battle.is_paused else "查看界面中 · 关闭后继续战斗")

func _go_to_action() -> void:
	var view: String = STEPS[clampi(battle.progression.guide_step, 0, 5)][3]
	if view == "inventory":
		if not inventory_ui.panel.visible: inventory_ui.toggle()
	elif not view.is_empty():
		feature_ui.open_view(view)
