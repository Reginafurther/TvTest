class_name BattleUnit
extends CharacterBody2D

const BattleMapScript = preload("res://scripts/battle_map.gd")
const FloatingTextScript = preload("res://scripts/floating_text.gd")

signal died(unit)
signal combat_event(message: String)
signal health_changed(unit)

var actor_id := ""
var actor_data: Dictionary = {}
var skill_data: Dictionary = {}
var faction := "heroes"
var battle
var hp := 1.0
var max_hp := 1.0
var attack := 1.0
var defense := 0.0
var move_speed := 80.0
var attack_range := 60.0
var attack_interval := 1.0
var attack_timer := 0.0
var skill_timer := 0.0
var target
var nav_path := PackedVector2Array()
var path_index := 0
var repath_timer := 0.0
var hit_flash := 0.0
var dead := false
var facing := 1.0
var rally_target := Vector2.ZERO
var has_rally := false

func setup(id: String, info: Dictionary, skill: Dictionary, team: String, owner_battle) -> void:
	actor_id = id
	actor_data = info
	skill_data = skill
	faction = team
	battle = owner_battle
	max_hp = float(info.get("max_hp", 100))
	hp = max_hp
	attack = float(info.get("attack", 10))
	defense = float(info.get("defense", 0))
	move_speed = float(info.get("move_speed", 80))
	attack_range = float(info.get("attack_range", 60))
	attack_interval = float(info.get("attack_interval", 1.0))
	skill_timer = randf_range(1.5, float(skill.get("cooldown", 6.0)))
	add_to_group(team)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or battle.is_paused:
		velocity = Vector2.ZERO
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	repath_timer -= delta
	hit_flash = maxf(0.0, hit_flash - delta)
	if not is_instance_valid(target) or target.dead:
		target = null
	if has_rally:
		if position.distance_to(rally_target) < 22.0:
			has_rally = false
			nav_path.clear()
		else:
			move_toward_point(rally_target, delta)
			return
	if target == null:
		target = battle.find_closest_enemy(self)
	if target == null:
		velocity = Vector2.ZERO
		return
	var distance := position.distance_to(target.position)
	if skill_timer <= 0.0 and try_use_skill():
		return
	if distance <= attack_range:
		velocity = Vector2.ZERO
		if attack_timer <= 0.0:
			basic_attack()
	else:
		move_toward_point(target.position, delta)

func move_toward_point(point: Vector2, _delta: float) -> void:
	if repath_timer <= 0.0 or nav_path.is_empty():
		nav_path = battle.find_path(position, point)
		path_index = 0
		repath_timer = 0.38 + randf() * 0.14
	while path_index < nav_path.size() and position.distance_to(nav_path[path_index]) < 14.0:
		path_index += 1
	var next_point := point if path_index >= nav_path.size() else nav_path[path_index]
	var direction := position.direction_to(next_point)
	velocity = direction * move_speed
	if absf(direction.x) > 0.05:
		facing = signf(direction.x)
	move_and_slide()
	position.x = clampf(position.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
	position.y = clampf(position.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	queue_redraw()

func basic_attack() -> void:
	attack_timer = attack_interval
	var amount := maxf(1.0, attack - target.defense * 0.55) * randf_range(0.9, 1.1)
	target.take_damage(amount, self)
	battle.spawn_tracer(position, target.position, _accent_color())

func try_use_skill() -> bool:
	var kind: String = skill_data.get("type", "")
	var cooldown := float(skill_data.get("cooldown", 6.0))
	var power := float(skill_data.get("power", 1.0))
	match kind:
		"heal_aura":
			var ally = battle.lowest_health_ally(self)
			if ally != null and ally.hp < ally.max_hp * 0.88:
				ally.heal(attack * power, self)
				battle.spawn_ring(ally.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，治疗 %s" % [_name(), _skill_name(), ally._name()])
				return true
		"self_heal":
			if hp < max_hp * 0.72:
				heal(max_hp * power, self)
				battle.spawn_ring(position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】恢复体力" % [_name(), _skill_name()])
				return true
		"chain":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", 220)):
				var victims: Array = battle.enemies_near(target.position, faction, 145.0, 3)
				for i in range(victims.size()):
					var victim = victims[i]
					victim.take_damage(attack * power * (1.0 - i * 0.18), self)
					battle.spawn_tracer(position if i == 0 else victims[i - 1].position, victim.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，命中 %d 个目标" % [_name(), _skill_name(), victims.size()])
				return true
		"damage":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", attack_range)):
				target.take_damage(attack * power, self)
				battle.spawn_ring(target.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				return true
	return false

func take_damage(raw_amount: float, source) -> void:
	if dead:
		return
	var amount := maxi(1, roundi(raw_amount))
	hp = maxf(0.0, hp - amount)
	hit_flash = 0.12
	show_number("-%d" % amount, Color("#FF8278"))
	health_changed.emit(self)
	queue_redraw()
	if hp <= 0.0:
		dead = true
		velocity = Vector2.ZERO
		combat_event.emit("%s 被 %s 击败" % [_name(), source._name()])
		died.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)

func heal(raw_amount: float, _source) -> void:
	var amount := mini(roundi(raw_amount), roundi(max_hp - hp))
	if amount <= 0:
		return
	hp += amount
	show_number("+%d" % amount, Color("#77F09D"))
	health_changed.emit(self)
	queue_redraw()

func show_number(value: String, tint: Color) -> void:
	var number = FloatingTextScript.new()
	number.setup(value, tint)
	add_child(number)

func set_rally(point: Vector2) -> void:
	rally_target = point
	has_rally = true
	target = null
	nav_path.clear()

func _draw() -> void:
	var base := Color(actor_data.get("color", "FFFFFF"))
	var accent := _accent_color()
	if hit_flash > 0:
		base = Color.WHITE
	# Soft shadow, oversized head and compact body form the placeholder chibi silhouette.
	draw_ellipse(Vector2(0, 17), Vector2(21, 8), Color(0.05, 0.08, 0.08, 0.22))
	draw_circle(Vector2(0, 5), 16, base.darkened(0.16))
	draw_rect(Rect2(-12, -2, 24, 26), base, true)
	draw_circle(Vector2(0, -14), 22, base)
	draw_circle(Vector2(-7, -17), 2.2, Color("#17202A"))
	draw_circle(Vector2(7, -17), 2.2, Color("#17202A"))
	draw_arc(Vector2(0, -9), 5, 0.2, PI - 0.2, 12, accent, 2)
	draw_arc(Vector2.ZERO, 17, 0, TAU, 24, accent, 3)
	if faction == "heroes":
		draw_circle(Vector2(0, -36), 4, Color("#68D6FF"))
	else:
		draw_circle(Vector2(0, -36), 4, Color("#FF6B60"))
	# HP bar
	draw_rect(Rect2(-24, -47, 48, 6), Color(0.08, 0.09, 0.1, 0.85), true)
	draw_rect(Rect2(-23, -46, 46 * (hp / max_hp), 4), Color("#65D97B") if faction == "heroes" else Color("#EE6158"), true)

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _name() -> String:
	return actor_data.get("name", actor_id)

func _skill_name() -> String:
	return skill_data.get("name", "技能")

func _accent_color() -> Color:
	return Color(actor_data.get("accent", "FFFFFF"))

func _skill_color() -> Color:
	return Color(skill_data.get("color", "FFFFFF"))

