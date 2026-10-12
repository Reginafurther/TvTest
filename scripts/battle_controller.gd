class_name BattleController
extends Node2D

const DataLoaderScript = preload("res://scripts/data_loader.gd")
const BattleMapScript = preload("res://scripts/battle_map.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const EffectRingScript = preload("res://scripts/effect_ring.gd")

signal stats_changed(kills: int, elapsed: float, wave: int)
signal party_changed(party: Array)
signal log_message(message: String)
signal battle_state_changed(message: String)

var actors: Dictionary
var skills: Dictionary
var battle_map: Node2D
var astar := AStarGrid2D.new()
var heroes: Array = []
var enemies: Array = []
var elapsed := 0.0
var kills := 0
var wave := 1
var spawn_timer := 0.0
var is_paused := false
var game_over := false
var obstacle_cells: Dictionary = {}

func _ready() -> void:
	actors = DataLoaderScript.load_json("res://data/actors.json")
	skills = DataLoaderScript.load_json("res://data/skills.json")
	battle_map = BattleMapScript.new()
	add_child(battle_map)
	setup_navigation()
	spawn_party()
	spawn_wave()

func setup_navigation() -> void:
	astar.region = Rect2i(0, 0, 34, 17)
	astar.cell_size = Vector2(32, 32)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for rect in battle_map.obstacles:
		var start := world_to_cell(rect.position - Vector2(16, 16))
		var finish := world_to_cell(rect.end + Vector2(16, 16))
		for x in range(start.x, finish.x + 1):
			for y in range(start.y, finish.y + 1):
				var cell := Vector2i(x, y)
				if astar.is_in_boundsv(cell):
					astar.set_point_solid(cell, true)

func spawn_party() -> void:
	var ids := ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
	for i in range(ids.size()):
		var pos := Vector2(120 + (i % 2) * 70, 190 + (i / 2) * 110)
		spawn_unit(ids[i], "heroes", pos)
	party_changed.emit(heroes)

func spawn_wave() -> void:
	if game_over:
		return
	var count := mini(3 + wave, 9)
	for i in range(count):
		var id := "yellow_turban" if (i + wave) % 2 == 0 else "zubat"
		var pos := Vector2(900 + randf_range(-50, 70), 70 + i * (380.0 / maxf(1, count - 1)) + randf_range(-18, 18))
		var enemy = spawn_unit(id, "enemies", pos)
		# Gentle wave scaling keeps the idle loop meaningful.
		enemy.max_hp *= 1.0 + (wave - 1) * 0.12
		enemy.hp = enemy.max_hp
		enemy.attack *= 1.0 + (wave - 1) * 0.07
	log_message.emit("第 %d 波敌人进入青草渡口" % wave)
	wave += 1

func spawn_unit(id: String, faction: String, pos: Vector2):
	var unit = BattleUnitScript.new()
	var data: Dictionary = actors.get(id, {})
	var skill: Dictionary = skills.get(data.get("skill", ""), {})
	unit.setup(id, data, skill, faction, self)
	unit.position = pos
	unit.died.connect(_on_unit_died)
	unit.combat_event.connect(_on_combat_event)
	unit.health_changed.connect(_on_health_changed)
	add_child(unit)
	if faction == "heroes":
		heroes.append(unit)
	else:
		enemies.append(unit)
	return unit

func _process(delta: float) -> void:
	if is_paused or game_over:
		return
	elapsed += delta
	if enemies.is_empty():
		spawn_timer += delta
		if spawn_timer >= 2.2:
			spawn_timer = 0.0
			spawn_wave()
	stats_changed.emit(kills, elapsed, wave - 1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_battle"):
		is_paused = not is_paused
		battle_state_changed.emit("已暂停" if is_paused else "自动战斗中")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local := to_local(event.position)
		if Rect2(Vector2.ZERO, BattleMapScript.ARENA_SIZE).has_point(local) and not point_blocked(local):
			battle_map.set_rally(local)
			for i in range(heroes.size()):
				if is_instance_valid(heroes[i]) and not heroes[i].dead:
					heroes[i].set_rally(local + Vector2((i % 2) * 38 - 19, (i / 2) * 38 - 19))
			log_message.emit("队伍移动至新的集结点")

func find_closest_enemy(seeker):
	var pool: Array = enemies if seeker.faction == "heroes" else heroes
	var closest
	var best := INF
	for candidate in pool:
		if is_instance_valid(candidate) and not candidate.dead:
			var distance = seeker.position.distance_squared_to(candidate.position)
			if distance < best:
				best = distance
				closest = candidate
	return closest

func lowest_health_ally(seeker):
	var pool: Array = heroes if seeker.faction == "heroes" else enemies
	var result
	var ratio := 2.0
	for ally in pool:
		if is_instance_valid(ally) and not ally.dead and seeker.position.distance_to(ally.position) <= 260:
			var current = ally.hp / ally.max_hp
			if current < ratio:
				ratio = current
				result = ally
	return result

func enemies_near(center: Vector2, source_faction: String, radius: float, limit: int) -> Array:
	var pool: Array = enemies if source_faction == "heroes" else heroes
	var found: Array = []
	for candidate in pool:
		if is_instance_valid(candidate) and not candidate.dead and candidate.position.distance_to(center) <= radius:
			found.append(candidate)
			if found.size() >= limit:
				break
	return found

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := nearest_open_cell(world_to_cell(from))
	var finish := nearest_open_cell(world_to_cell(to))
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(finish):
		return PackedVector2Array([to])
	return astar.get_point_path(start, finish)

func nearest_open_cell(cell: Vector2i) -> Vector2i:
	cell.x = clampi(cell.x, 0, 33)
	cell.y = clampi(cell.y, 0, 16)
	if not astar.is_point_solid(cell):
		return cell
	for radius in range(1, 5):
		for x in range(cell.x - radius, cell.x + radius + 1):
			for y in range(cell.y - radius, cell.y + radius + 1):
				var test := Vector2i(x, y)
				if astar.is_in_boundsv(test) and not astar.is_point_solid(test):
					return test
	return cell

func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 32.0), floori(point.y / 32.0))

func point_blocked(point: Vector2) -> bool:
	for rect in battle_map.obstacles:
		if rect.grow(18).has_point(point):
			return true
	return false

func _on_unit_died(unit) -> void:
	if unit.faction == "enemies":
		enemies.erase(unit)
		kills += 1
	else:
		heroes.erase(unit)
		party_changed.emit(heroes)
		if heroes.is_empty():
			game_over = true
			battle_state_changed.emit("队伍全灭 · 按 R 重新开始")

func _on_combat_event(message: String) -> void:
	log_message.emit(message)

func _on_health_changed(_unit) -> void:
	party_changed.emit(heroes)

func spawn_tracer(from: Vector2, to: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 3.0
	line.default_color = color
	add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.18)
	tween.tween_callback(line.queue_free)

func spawn_ring(at: Vector2, color: Color) -> void:
	var ring = EffectRingScript.new()
	ring.position = at
	ring.tint = color
	add_child(ring)

func restart() -> void:
	get_tree().reload_current_scene()

