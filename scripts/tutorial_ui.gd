class_name TutorialUI
extends CanvasLayer

const STEPS := [
	["1/6 初始招募", "你有 1 枚招募令。点击“招募”，获得第一位新伙伴。", "招募", "recruit"],
	["2/6 自动战斗", "战斗自动进行。观察角色索敌、移动与击败怪物；点击地图可设集结点。", "查看地图", ""],
	["3/6 获得装备", "怪物会随机掉装备，拾取自动完成。等待掉落后打开背包。", "背包", "inventory"],
	["4/6 穿戴装备", "在背包选装备，比较绿色提升与红色降低，再为伙伴穿戴。", "背包", "inventory"],
	["5/6 招募伙伴", "继续挂机获得世界材料，在招募界面双击角色定向兑换。", "招募", "recruit"],
	["6/6 编队与挑战", "在“伙伴”调整四人队伍；“世界”切地图，“Boss”看挑战信息。", "伙伴", "party"]
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
	panel.position = Vector2(8, 160)
	panel.size = Vector2(166, 315)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142832")
	style.border_color = Color("#E5BC66")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#FFF0B4"))
	box.add_child(title)
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(140, 140)
	box.add_child(description)
	action_button = Button.new()
	action_button.pressed.connect(_go_to_action)
	box.add_child(action_button)
	replay_next = Button.new()
	replay_next.text = "已了解，下一步"
	replay_next.pressed.connect(func(): battle.progression.set_guide_step(battle.progression.guide_step + 1))
	box.add_child(replay_next)
	var skip := Button.new()
	skip.text = "跳过引导"
	skip.pressed.connect(func(): battle.progression.skip_guide())
	box.add_child(skip)
	objective = Label.new()
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.add_theme_color_override("font_color", Color("#A8D9E9"))
	box.add_child(objective)

func _process(_delta: float) -> void:
	if not battle.progression.guide_finished:
		advance_from_state()

func advance_from_state() -> void:
	var p = battle.progression
	if p.guide_replay: return
	var done := false
	match p.guide_step:
		0: done = p.recruit_tokens == 0 and p.roster.size() >= 5
		1: done = battle.kills > initial_kills
		2: done = battle.inventory.items.size() > initial_items
		3:
			for actor_id in p.roster:
				for item_id in battle.inventory.equipped.get(actor_id, {}).values():
					if not str(item_id).is_empty(): done = true
		4: done = p.roster.size() >= 6
		5: done = p.party != initial_party or battle.current_map_id != "hulao_pass"
	if done:
		p.set_guide_step(p.guide_step + 1)
		if p.guide_step == 2: initial_items = battle.inventory.items.size()
		refresh()

func refresh() -> void:
	if panel == null: return
	var p = battle.progression
	panel.visible = not p.guide_finished
	if p.guide_finished: return
	var step: int = clampi(p.guide_step, 0, 5)
	title.text = STEPS[step][0]
	description.text = STEPS[step][1]
	action_button.text = "前往：" + STEPS[step][2]
	replay_next.visible = p.guide_replay
	objective.text = "回顾模式 · 点下一步" if p.guide_replay else ("正在进行 · 不会阻止战斗" if not battle.is_paused else "查看界面中 · 关闭后继续战斗")

func _go_to_action() -> void:
	var view: String = STEPS[clampi(battle.progression.guide_step, 0, 5)][3]
	if view == "inventory":
		if not inventory_ui.panel.visible: inventory_ui.toggle()
	elif not view.is_empty():
		feature_ui.open_view(view)
