class_name BattleUnit
extends CharacterBody2D

const BattleMapScript = preload("res://scripts/battle_map.gd")
const FloatingTextScript = preload("res://scripts/floating_text.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")

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
var base_max_hp := 1.0
var base_attack := 1.0
var base_defense := 0.0
var base_attack_interval := 1.0
var move_speed := 80.0
var attack_range := 60.0
var attack_interval := 1.0
var crit_chance := 0.05
var crit_damage := 1.5
var attack_speed := 0.0
var cooldown_reduction := 0.0
var physical_damage := 0.0
var elemental_damage := 0.0
var life_regen := 0.0
var regen_accumulator := 0.0
var equipment_rules: Dictionary = {}
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
var special_effects: Array = []
var shield := 0.0
var poison_damage := 0.0
var poison_time := 0.0
var poison_tick := 0.0
var poison_depth := 0
var poison_source
var last_damage_source
var taunt_timer := 0.0
var control_resistance := 0.0
var accumulated_control := 0.0
var actor_level := 1
var active_skill_level := 1
var passive_skill_level := 1
var passive_skill_id := ""
var passive_data: Dictionary = {}
var basic_attack_count := 0
var monster_level := 1
var enemy_type := "normal"
var reward_claimed := false

func setup(id: String, info: Dictionary, skill: Dictionary, team: String, owner_battle) -> void:
	actor_id = id
	actor_data = info
	skill_data = skill
	faction = team
	battle = owner_battle
	if team == "heroes" and battle.progression != null:
		actor_level = battle.progression.actor_level(id)
		active_skill_level = battle.progression.skill_level(id, "active")
		passive_skill_level = battle.progression.skill_level(id, "passive")
	passive_skill_id = info.get("passive_skill", info.get("talent", ""))
	passive_data = battle.passives_config.get(passive_skill_id, {})
	base_max_hp = float(info.get("max_hp", 100)) * (1.0 + (actor_level - 1) * 0.08)
	base_attack = float(info.get("attack", 10)) * (1.0 + (actor_level - 1) * 0.06)
	base_defense = float(info.get("defense", 0)) * (1.0 + (actor_level - 1) * 0.05)
	base_attack_interval = float(info.get("attack_interval", 1.0))
	max_hp = base_max_hp
	hp = max_hp
	attack = base_attack
	defense = base_defense
	move_speed = float(info.get("move_speed", 80))
	attack_range = float(info.get("attack_range", 60))
	attack_interval = base_attack_interval
	skill_timer = randf_range(1.5, float(skill.get("cooldown", 6.0)))
	if info.has("boss_id"):
		control_resistance = 0.35
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
	taunt_timer = maxf(0.0, taunt_timer - delta)
	if poison_time > 0.0:
		poison_time -= delta
		poison_tick += delta
		if poison_tick >= 1.0:
			poison_tick -= 1.0
			take_damage(poison_damage, poison_source, false, {"kind": "effect", "allow_triggers": false, "poison": true})
	if life_regen > 0.0 and hp < max_hp:
		regen_accumulator += delta
		if regen_accumulator >= 1.0:
			regen_accumulator -= 1.0
			heal(life_regen, self, false)
	if not is_instance_valid(target) or target.dead:
		target = null
	if has_rally:
		if position.distance_to(rally_target) < 22.0:
			has_rally = false
			nav_path.clear()
		else:
			move_toward_point(rally_target, delta)
			return
	if faction == "heroes" and actor_data.get("basic_action", "damage") == "heal":
		process_healer(delta)
		return
	if target == null:
		target = battle.find_closest_enemy(self)
	if target == null:
		velocity = Vector2.ZERO
		return
	var distance := position.distance_to(target.position)
	if skill_timer <= 0.0 and battle.strategy_allows(self) and try_use_skill():
		return
	if faction == "heroes" and actor_data.get("combat_style", "melee") == "ranged":
		var preferred := float(actor_data.get("preferred_range", attack_range * 0.8))
		if distance < preferred * 0.58:
			move_away_from_point(target.position)
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

func move_away_from_point(point: Vector2) -> void:
	var direction := point.direction_to(position)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if facing > 0 else Vector2.RIGHT
	velocity = direction.normalized() * move_speed
	facing = signf(velocity.x) if absf(velocity.x) > 0.05 else facing
	move_and_slide()
	position.x = clampf(position.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
	position.y = clampf(position.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	queue_redraw()

func process_healer(delta: float) -> void:
	var danger = battle.find_closest_enemy(self)
	var preferred := float(actor_data.get("preferred_range", 155.0))
	if is_instance_valid(danger) and position.distance_to(danger.position) < preferred * 0.62:
		move_away_from_point(danger.position)
		return
	var ally = battle.lowest_health_ally(self, 9999.0)
	if ally == null:
		velocity = Vector2.ZERO
		return
	target = ally
	if skill_timer <= 0.0 and battle.strategy_allows(self) and try_use_skill():
		return
	if position.distance_to(ally.position) > attack_range:
		move_toward_point(ally.position, delta)
	elif attack_timer <= 0.0:
		basic_attack()
	else:
		velocity = Vector2.ZERO

func basic_attack() -> void:
	attack_timer = attack_interval
	if actor_data.get("basic_action", "damage") == "heal" and is_instance_valid(target) and target.faction == faction:
		var healing_bonus := passive_value() if passive_data.get("effect", "") == "healing" else 0.0
		target.heal(attack * 0.72 * (1.0 + healing_bonus), self)
		if healing_bonus > 0.0:
			battle.note_passive(actor_id, passive_skill_id)
		battle.spawn_tracer(position, target.position, Color("#78F0A8"))
		return
	var amount := attack * (1.0 + physical_damage) * randf_range(0.9, 1.1)
	if passive_data.get("effect", "") == "low_hp_rage" and hp / max_hp < 0.4:
		amount *= 1.0 + passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if passive_data.get("effect", "") == "boss_slayer" and target.actor_data.has("boss_id"):
		amount *= 1.0 + passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if actor_data.get("boss_id", "") == "lu_bu" and hp / max_hp < 0.5:
		amount *= 1.45
	var critical := randf() < crit_chance
	if critical:
		amount *= crit_damage
	target.take_damage(amount, self, critical, {"kind": "basic", "critical": critical, "allow_triggers": true})
	basic_attack_count += 1
	if passive_data.get("effect", "") == "combo" and basic_attack_count % 3 == 0 and is_instance_valid(target) and not target.dead:
		target.take_damage(attack * passive_value(), self, false, {"kind": "passive", "allow_triggers": true})
		battle.note_passive(actor_id, passive_skill_id)
	battle.spawn_tracer(position, target.position, _accent_color())

func try_use_skill() -> bool:
	var kind: String = skill_data.get("type", "")
	var cooldown := effective_cooldown(float(skill_data.get("cooldown", 6.0)))
	var power := active_skill_power()
	match kind:
		"heal_aura":
			var ally = battle.lowest_health_ally(self)
			if ally != null and ally.hp < ally.max_hp * 0.88:
				var healing_bonus := passive_value() if passive_data.get("effect", "") == "healing" else 0.0
				ally.heal(attack * power * (1.0 + healing_bonus), self)
				ally.add_shield(attack * (1.0 + healing_bonus))
				if healing_bonus > 0.0: battle.note_passive(actor_id, passive_skill_id)
				battle.spawn_ring(ally.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，治疗 %s" % [_name(), _skill_name(), ally._name()])
				battle.on_skill(self)
				return true
		"self_heal":
			if hp < max_hp * 0.72:
				heal(max_hp * power, self)
				battle.spawn_ring(position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】恢复体力" % [_name(), _skill_name()])
				battle.on_skill(self)
				return true
		"chain":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", 220)):
				var victims: Array = battle.enemies_near(target.position, faction, 145.0, 3)
				for i in range(victims.size()):
					var victim = victims[i]
					victim.take_damage(attack * power * (1.0 + elemental_damage) * (1.0 - i * 0.18), self, false, {"kind": "skill", "allow_triggers": true})
					battle.spawn_tracer(position if i == 0 else victims[i - 1].position, victim.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，命中 %d 个目标" % [_name(), _skill_name(), victims.size()])
				battle.on_skill(self)
				return true
		"damage":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", attack_range)):
				target.take_damage(attack * power * (1.0 + physical_damage), self, false, {"kind": "skill", "allow_triggers": true})
				battle.spawn_ring(target.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				battle.on_skill(self)
				return true
		"poison":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", 210)):
				target.take_damage(attack * 0.65, self, false, {"kind": "skill", "allow_triggers": true})
				var poison_bonus := passive_value() if passive_data.get("effect", "") == "poison_master" else 0.0
				target.apply_poison(attack * power * (1.0 + poison_bonus), float(skill_data.get("duration", 6.0)) * (1.0 + poison_bonus * 0.5), self, 0)
				if poison_bonus > 0.0: battle.note_passive(actor_id, passive_skill_id)
				skill_timer = cooldown
				battle.on_skill(self)
				combat_event.emit("%s 施放【%s】，目标中毒" % [_name(), _skill_name()])
				return true
		"area_damage", "boss_area":
			var victims: Array = battle.enemies_near(position, faction, float(skill_data.get("range", 170)), 12)
			if not victims.is_empty():
				for victim in victims:
					var damage := attack * power * (1.0 + elemental_damage)
					if passive_data.get("effect", "") == "boss_slayer" and victim.actor_data.has("boss_id"):
						damage *= 1.0 + passive_value()
						battle.note_passive(actor_id, passive_skill_id)
					victim.take_damage(damage, self, false, {"kind": "skill", "allow_triggers": true})
				if actor_data.get("boss_id", "") == "mewtwo":
					add_shield(max_hp * 0.12)
				skill_timer = cooldown
				battle.on_skill(self)
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				return true
		"taunt":
			var victims: Array = battle.enemies_near(position, faction, float(skill_data.get("range", 230)), 12)
			for victim in victims:
				victim.target = self
				victim.taunt_timer = float(skill_data.get("duration", 3.0))
			add_shield(max_hp * power)
			skill_timer = cooldown
			battle.on_skill(self)
			return true
		"team_haste":
			var allies: Array = battle.heroes if faction == "heroes" else battle.enemies
			for ally in allies:
				if is_instance_valid(ally): ally.skill_timer *= maxf(0.35, 1.0 - power)
			skill_timer = cooldown
			battle.on_skill(self)
			return true
	return false

func take_damage(raw_amount: float, source, critical: bool = false, context: Dictionary = {}) -> void:
	if dead:
		return
	var amount := preview_damage(raw_amount)
	if passive_data.get("effect", "") == "damage_reduction":
		amount = roundi(amount * (1.0 - passive_value()))
		battle.note_passive(actor_id, passive_skill_id)
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= roundi(absorbed)
		if shield <= 0.0 and absorbed > 0.0 and has_special("shield_burst"):
			trigger_shield_burst()
	if amount <= 0:
		return
	last_damage_source = source
	hp = maxf(0.0, hp - amount)
	hit_flash = 0.12
	show_number(("暴击 -%d" if critical else "-%d") % amount, Color("#FFE26A") if critical else Color("#FF8278"))
	health_changed.emit(self)
	battle.on_damage(source, self, amount, context)
	queue_redraw()
	if hp <= 0.0:
		dead = true
		velocity = Vector2.ZERO
		combat_event.emit("%s 被 %s 击败" % [_name(), source._name()])
		if poison_time > 0.0 and is_instance_valid(poison_source) and poison_source.has_special("poison_spread"):
			battle.propagate_poison(self)
		died.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)

func preview_damage(raw_amount: float) -> int:
	return maxi(1, roundi(maxf(1.0, raw_amount - defense * 0.55)))

func heal(raw_amount: float, _source, show_text: bool = true) -> void:
	var amount := mini(roundi(raw_amount), roundi(max_hp - hp))
	if amount <= 0:
		return
	hp += amount
	battle.on_heal(_source, amount)
	if show_text:
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

func set_special_effects(effects: Array) -> void:
	special_effects = effects.duplicate()

func has_special(id: String) -> bool:
	return id in special_effects

func add_shield(amount: float) -> void:
	shield = maxf(shield, amount)
	show_number("◆ 护盾", Color("#80C8FF"))
	queue_redraw()

func apply_poison(damage_per_second: float, duration: float, source, depth: int) -> void:
	poison_damage = maxf(poison_damage, damage_per_second)
	poison_time = maxf(poison_time, duration)
	poison_source = source
	poison_depth = depth
	show_number("☠ 中毒", Color("#C58DFF"))
	queue_redraw()

func apply_hard_control(duration: float) -> float:
	# Boss hard-control duration diminishes per application and is capped cumulatively.
	var cap := 4.0 if actor_data.has("boss_id") else 8.0
	var applied := minf(duration * (1.0 - control_resistance), maxf(0.0, cap - accumulated_control))
	accumulated_control += applied
	if actor_data.has("boss_id"):
		control_resistance = minf(0.85, control_resistance + 0.15)
	attack_timer += applied
	skill_timer += applied
	return applied

func trigger_shield_burst() -> void:
	var effect: Dictionary = battle.special_config.effects.shield_burst
	battle.note_effect("shield_burst")
	for victim in battle.enemies_near(position, faction, float(effect.range), int(effect.max_targets)):
		victim.take_damage(attack * float(effect.power), self, false, {"kind": "effect", "allow_triggers": false})

func apply_equipment_stats(stats: Dictionary, rules: Dictionary) -> void:
	var hp_ratio := hp / maxf(1.0, max_hp)
	equipment_rules = rules
	max_hp = base_max_hp + float(stats.get("health", 0))
	attack = base_attack + float(stats.get("attack", 0))
	defense = base_defense + float(stats.get("defense", 0))
	crit_chance = clampf(0.05 + float(stats.get("crit_chance", 0)), 0.0, float(rules.get("max_crit_chance", 0.75)))
	crit_damage = maxf(1.0, 1.5 + float(stats.get("crit_damage", 0)))
	attack_speed = clampf(float(stats.get("attack_speed", 0)), 0.0, float(rules.get("max_attack_speed", 1.5)))
	cooldown_reduction = clampf(float(stats.get("cooldown_reduction", 0)), 0.0, float(rules.get("max_cooldown_reduction", 0.5)))
	physical_damage = maxf(-0.9, float(stats.get("physical_damage", 0)))
	elemental_damage = maxf(-0.9, float(stats.get("elemental_damage", 0)))
	life_regen = maxf(0.0, float(stats.get("life_regen", 0)))
	match passive_data.get("effect", ""):
		"health_regen":
			max_hp *= 1.0 + passive_value()
			life_regen += float(passive_data.get("regen", 0.0)) * (1.0 + (passive_skill_level - 1) * 0.12)
		"attack_speed":
			attack_speed = clampf(attack_speed + passive_value(), 0.0, float(rules.get("max_attack_speed", 1.5)))
		"elemental_damage":
			elemental_damage += passive_value()
	attack_interval = maxf(float(rules.get("min_attack_interval", 0.25)), base_attack_interval / (1.0 + attack_speed))
	hp = clampf(max_hp * hp_ratio, 1.0 if not dead else 0.0, max_hp)
	health_changed.emit(self)
	queue_redraw()

func refresh_progression_stats() -> void:
	if faction != "heroes" or battle.progression == null:
		return
	actor_level = battle.progression.actor_level(actor_id)
	active_skill_level = battle.progression.skill_level(actor_id, "active")
	passive_skill_level = battle.progression.skill_level(actor_id, "passive")
	base_max_hp = float(actor_data.get("max_hp", 100)) * (1.0 + (actor_level - 1) * 0.08)
	base_attack = float(actor_data.get("attack", 10)) * (1.0 + (actor_level - 1) * 0.06)
	base_defense = float(actor_data.get("defense", 0)) * (1.0 + (actor_level - 1) * 0.05)
	apply_equipment_stats(battle.inventory.get_actor_stats(actor_id), battle.equipment_config.get("rules", {}))

func effective_cooldown(base_cooldown: float) -> float:
	var level_reduction := float(skill_data.get("cooldown_per_level", 0.0)) * (active_skill_level - 1)
	var team_haste: float = battle.party_passive_value("team_haste") if faction == "heroes" else 0.0
	return maxf(0.5, base_cooldown * (1.0 - cooldown_reduction) * (1.0 - level_reduction) * (1.0 - minf(0.35, team_haste)))

func active_skill_power() -> float:
	return float(skill_data.get("power", 1.0)) * (1.0 + float(skill_data.get("power_per_level", 0.0)) * (active_skill_level - 1))

func passive_value() -> float:
	return float(passive_data.get("value", 0.0)) + float(passive_data.get("per_level", 0.0)) * (passive_skill_level - 1)

func combat_snapshot() -> Dictionary:
	return {
		"health": max_hp,
		"attack": attack,
		"defense": defense,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
		"attack_speed": attack_speed,
		"cooldown_reduction": cooldown_reduction,
		"physical_damage": physical_damage,
		"elemental_damage": elemental_damage,
		"life_regen": life_regen,
		"attack_interval": attack_interval,
		"actor_level": actor_level,
		"active_skill_level": active_skill_level,
		"passive_skill_level": passive_skill_level
	}

func _draw() -> void:
	var base := Color(actor_data.get("color", "FFFFFF"))
	var accent := _accent_color()
	if hit_flash > 0:
		base = Color.WHITE
	# Soft shadow, oversized head and compact body form the placeholder chibi silhouette.
	draw_chibi_ellipse(Vector2(0, 17), Vector2(21, 8), Color(0.05, 0.08, 0.08, 0.22))
	var artwork: Texture2D = ArtCatalogScript.texture("units", actor_id)
	if artwork != null:
		draw_texture_rect(artwork, Rect2(-38, -58, 76, 83), false)
	else:
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
	if shield > 0:
		draw_arc(Vector2.ZERO, 28, 0, TAU, 24, Color("#80C8FF"), 3)
	if poison_time > 0:
		draw_circle(Vector2(23, -37), 5, Color("#C58DFF"))

func draw_chibi_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
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
