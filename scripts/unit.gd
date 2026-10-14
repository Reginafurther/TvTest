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
var nav_goal := Vector2(-9999, -9999)
var hit_flash := 0.0
var dead := false
var facing := 1.0
var rally_target := Vector2.ZERO
var has_rally := false
var special_effects: Array = []
var shield := 0.0
var shield_time := 0.0
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
var general_active_ids: Array = []
var general_passive_ids: Array = []
var general_active_timers: Dictionary = {}
var general_passive_datas: Array = []
var burn_damage := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var burn_source
var hot_amount := 0.0
var hot_time := 0.0
var hot_tick := 0.0
var hot_source
var slow_time := 0.0
var slow_power := 0.0
var temporary_reduction_time := 0.0
var temporary_reduction := 0.0
var temporary_evasion_time := 0.0
var temporary_evasion := 0.0
var temporary_counter_time := 0.0
var temporary_counter := 0.0
var damage_share_time := 0.0
var damage_share_ratio := 0.0
var damage_share_source
var haste_time := 0.0
var haste_power := 0.0
var armor_break_time := 0.0
var armor_break_power := 0.0
var shock_time := 0.0
var home_position := Vector2.ZERO
var current_action := "idle"
var target_refresh_timer := 0.0

func setup(id: String, info: Dictionary, skill: Dictionary, team: String, owner_battle) -> void:
	actor_id = id
	actor_data = info
	skill_data = skill
	faction = team
	battle = owner_battle
	# Allies must not body-block their own formation; opposing factions still collide.
	collision_layer = 1 if team == "heroes" else 2
	collision_mask = 2 if team == "heroes" else 1
	if team == "heroes" and battle.progression != null:
		actor_level = battle.progression.actor_level(id)
		active_skill_level = battle.progression.skill_level(id, "active")
		passive_skill_level = battle.progression.skill_level(id, "passive")
		general_active_ids = battle.progression.equipped_skill_ids(id, "active")
		general_passive_ids = battle.progression.equipped_skill_ids(id, "passive")
		for general_id in general_passive_ids:
			var general_data: Dictionary = battle.general_skills_config.get(general_id, {})
			if not general_data.is_empty(): general_passive_datas.append({"id": general_id, "data": general_data})
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
	for general_id in general_active_ids:
		general_active_timers[general_id] = randf_range(1.2, float(battle.general_skills_config.get(general_id, {}).get("cooldown", 7.0)))
	if info.has("boss_id"):
		control_resistance = 0.35
		if info.get("boss_mechanic", "") == "regeneration": life_regen = max_hp * 0.012
	add_to_group(team)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 23.0 if info.has("boss_id") else 16.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead or battle.is_paused:
		velocity = Vector2.ZERO
		current_action = "paused"
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	for general_id in general_active_timers:
		general_active_timers[general_id] = maxf(0.0, float(general_active_timers[general_id]) - delta)
	target_refresh_timer = maxf(0.0, target_refresh_timer - delta)
	repath_timer -= delta
	hit_flash = maxf(0.0, hit_flash - delta)
	taunt_timer = maxf(0.0, taunt_timer - delta)
	temporary_reduction_time = maxf(0.0, temporary_reduction_time - delta)
	if shield_time > 0.0:
		shield_time = maxf(0.0, shield_time - delta)
		if shield_time <= 0.0 and shield > 0.0:
			shield = 0.0
			show_number("护盾消散", Color("#A8D9FF"))
			queue_redraw()
	temporary_evasion_time = maxf(0.0, temporary_evasion_time - delta)
	temporary_counter_time = maxf(0.0, temporary_counter_time - delta)
	damage_share_time = maxf(0.0, damage_share_time - delta)
	haste_time = maxf(0.0, haste_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	armor_break_time = maxf(0.0, armor_break_time - delta)
	shock_time = maxf(0.0, shock_time - delta)
	if poison_time > 0.0:
		poison_time -= delta
		poison_tick += delta
		if poison_tick >= 1.0:
			poison_tick -= 1.0
			take_damage(poison_damage, poison_source, false, {"kind": "effect", "allow_triggers": false, "poison": true})
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick += delta
		if burn_tick >= 1.0:
			burn_tick -= 1.0
			take_damage(burn_damage, burn_source, false, {"kind": "effect", "allow_triggers": false, "burn": true})
	if hot_time > 0.0:
		hot_time -= delta
		hot_tick += delta
		if hot_tick >= 1.0:
			hot_tick -= 1.0
			heal(hot_amount, hot_source, false)
	if life_regen > 0.0 and hp < max_hp:
		regen_accumulator += delta
		if regen_accumulator >= 1.0:
			regen_accumulator -= 1.0
			heal(life_regen, self, false)
	if not is_instance_valid(target) or target.dead:
		target = null
	if faction == "heroes" and taunt_timer <= 0.0 and target_refresh_timer <= 0.0:
		target = battle.select_combat_target(self)
		target_refresh_timer = 0.65
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
		target = battle.select_combat_target(self)
	if target == null:
		return_to_formation(delta)
		return
	var distance := position.distance_to(target.position)
	if faction == "heroes" and actor_data.get("combat_style", "melee") == "ranged":
		var minimum_safe := float(actor_data.get("minimum_safe_distance", attack_range * 0.5))
		if distance < minimum_safe:
			current_action = "retreat"
			move_toward_point(battle.tactical_ranged_point(self, target), delta)
			return
		if distance <= attack_range:
			if try_auto_skills(): return
			velocity = Vector2.ZERO
			current_action = "hold_range"
			if attack_timer <= 0.0: basic_attack()
			return
		if try_auto_skills(): return
		current_action = "seek_firing_position"
		move_toward_point(battle.tactical_ranged_point(self, target), delta)
		return
	if faction == "heroes" and actor_data.get("combat_role", "") == "tank" and distance <= 150.0:
		var threatened_role := str(target.target.actor_data.get("combat_role", "")) if is_instance_valid(target.target) else ""
		if threatened_role in ["ranged_dps", "healer"]:
			target.target = self
			target.taunt_timer = maxf(target.taunt_timer, 1.25)
	if try_auto_skills():
		return
	if distance <= attack_range:
		velocity = Vector2.ZERO
		current_action = "engage"
		if attack_timer <= 0.0:
			basic_attack()
	else:
		current_action = "advance"
		move_toward_point(target.position, delta)

func move_toward_point(point: Vector2, _delta: float) -> void:
	var goal_shifted := nav_goal.distance_to(point) > 28.0
	if nav_path.is_empty() or path_index >= nav_path.size() or (repath_timer <= 0.0 and goal_shifted):
		nav_path = battle.find_path(position, point)
		path_index = 0
		nav_goal = point
		repath_timer = 0.38 + randf() * 0.14
	# AStarGrid includes the current cell centre as its first point. Slow units used
	# to walk backwards toward that point until the next repath, causing a loop.
	# Skip waypoints within roughly one grid cell so every repath advances.
	while path_index < nav_path.size() and position.distance_to(nav_path[path_index]) < 36.0:
		path_index += 1
	var next_point := point if path_index >= nav_path.size() else nav_path[path_index]
	var direction := position.direction_to(next_point)
	var speed_factor := (1.0 + haste_power if haste_time > 0.0 else 1.0) * (1.0 - slow_power if slow_time > 0.0 else 1.0)
	velocity = direction * move_speed * maxf(0.15, speed_factor)
	if absf(direction.x) > 0.05:
		facing = signf(direction.x)
	move_and_slide()
	position.x = clampf(position.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
	position.y = clampf(position.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	queue_redraw()

func return_to_formation(delta: float) -> void:
	if faction == "heroes" and home_position != Vector2.ZERO and position.distance_to(home_position) > 32.0:
		current_action = "return_formation"
		move_toward_point(home_position, delta)
	else:
		current_action = "hold_formation"
		velocity = Vector2.ZERO

func move_away_from_point(point: Vector2) -> void:
	var direction := point.direction_to(position)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if facing > 0 else Vector2.RIGHT
	var speed_factor := (1.0 + haste_power if haste_time > 0.0 else 1.0) * (1.0 - slow_power if slow_time > 0.0 else 1.0)
	velocity = direction.normalized() * move_speed * maxf(0.15, speed_factor)
	facing = signf(velocity.x) if absf(velocity.x) > 0.05 else facing
	move_and_slide()
	position.x = clampf(position.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
	position.y = clampf(position.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	queue_redraw()

func process_healer(delta: float) -> void:
	var danger = battle.find_closest_enemy(self)
	var minimum_safe := float(actor_data.get("minimum_safe_distance", 120.0))
	if is_instance_valid(danger) and position.distance_to(danger.position) < minimum_safe:
		current_action = "retreat"
		move_toward_point(battle.tactical_ranged_point(self, danger), delta)
		return
	var ally = battle.lowest_health_ally(self, 9999.0)
	if ally == null or ally.hp >= ally.max_hp * 0.995:
		target = null
		return_to_formation(delta)
		return
	target = ally
	if try_auto_skills():
		return
	if position.distance_to(ally.position) > attack_range:
		current_action = "seek_heal_range"
		move_toward_point(ally.position, delta)
	elif attack_timer <= 0.0:
		basic_attack()
	else:
		current_action = "heal_ready"
		velocity = Vector2.ZERO

func basic_attack() -> void:
	attack_timer = attack_interval / (1.0 + haste_power if haste_time > 0.0 else 1.0)
	current_action = "basic_attack"
	if actor_data.get("basic_action", "damage") == "heal" and is_instance_valid(target) and target.faction == faction:
		var healing_bonus := (passive_value() if passive_data.get("effect", "") == "healing" else 0.0) + passive_effect_total("healing")
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
	if actor_data.get("boss_mechanic", "") == "berserk" and hp / max_hp < 0.5:
		amount *= 1.35
	var critical := randf() < crit_chance
	if critical:
		amount *= crit_damage
	if target.has_negative_status(): amount *= 1.0 + passive_effect_total("status_amplifier")
	target.take_damage(amount, self, critical, {"kind": "basic", "critical": critical, "allow_triggers": true})
	match str(actor_data.get("boss_mechanic", "")):
		"venom_strike": target.apply_poison(attack * 0.12, 4.0, self, 0)
		"shock_strike": target.apply_shock(2.2)
		"regeneration": heal(amount * 0.16, self, false)
	trigger_general_on_hit(target)
	basic_attack_count += 1
	if passive_data.get("effect", "") == "combo" and basic_attack_count % 3 == 0 and is_instance_valid(target) and not target.dead:
		target.take_damage(attack * passive_value(), self, false, {"kind": "passive", "allow_triggers": true})
		battle.note_passive(actor_id, passive_skill_id)
	battle.spawn_tracer(position, target.position, _accent_color())

func try_auto_skills() -> bool:
	var priority: Array = battle.progression.skill_priorities.get(actor_id, ["exclusive", "general"]) if faction == "heroes" else ["exclusive"]
	for kind in priority:
		if kind == "general" and try_use_next_general_skill():
			current_action = "general_skill"
			return true
		if kind == "exclusive" and skill_timer <= 0.0 and battle.strategy_allows(self) and try_use_skill():
			current_action = "exclusive_skill"
			return true
	return false

func try_use_next_general_skill() -> bool:
	for skill_id in general_active_ids:
		if float(general_active_timers.get(skill_id, 9999.0)) <= 0.0 and try_use_general_skill(skill_id):
			return true
	return false

func try_use_general_skill(skill_id: String) -> bool:
	var data: Dictionary = battle.general_skills_config.get(skill_id, {})
	if data.is_empty(): return false
	var level: int = battle.progression.general_skill_level(actor_id, skill_id)
	var power: float = float(data.get("power", 1.0)) * (1.0 + float(data.get("power_per_level", 0.0)) * (level - 1))
	var cast_range := float(data.get("range", maxf(attack_range, 180.0)))
	var enemy = battle.find_closest_enemy(self)
	var ally = battle.lowest_health_ally(self, cast_range)
	var used := false
	match str(data.get("effect", "")):
		"damage":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power * (1.0 + physical_damage), self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"stun":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				enemy.apply_hard_control(float(data.get("duration", 1.2)))
				used = true
		"low_hp_damage":
			if valid_enemy_in_range(enemy, cast_range):
				var low_hp_multiplier := 1.65 if hp / maxf(1.0, max_hp) <= 0.4 else 1.0
				enemy.take_damage(attack * power * low_hp_multiplier, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"multi_hit":
			if valid_enemy_in_range(enemy, cast_range):
				var bonus := 1.0 + passive_effect_total("multi_hit_bonus")
				for _hit in range(int(data.get("hits", 3))): enemy.take_damage(attack * power * bonus, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true, "multi_hit":true})
				used = true
		"area_damage":
			if valid_enemy_in_range(enemy, cast_range):
				for victim in battle.enemies_near(enemy.position, faction, 125.0, 6): victim.take_damage(attack * power * (1.0 + elemental_damage), self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				battle.spawn_ring(enemy.position, Color("#F2C66D")); used = true
		"chain":
			if valid_enemy_in_range(enemy, cast_range):
				var victims: Array = battle.enemies_near(enemy.position, faction, 190.0, int(data.get("targets", 4)))
				for index in range(victims.size()): victims[index].take_damage(attack * power * (1.0 - index * 0.12), self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"armor_break":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				enemy.apply_armor_break(float(data.get("armor_break", 0.25)), float(data.get("duration", 5.0))); used = true
		"burn", "poison":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				var mastery := 1.0 + passive_status_mastery(str(data.effect))
				if data.effect == "burn": enemy.apply_burn(attack * float(data.get("dot_power", 0.18)) * mastery, float(data.get("duration", 5.0)) * mastery, self)
				else: enemy.apply_poison(attack * float(data.get("dot_power", 0.18)) * mastery, float(data.get("duration", 6.0)) * mastery, self, 0)
				used = true
		"shock":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true}); enemy.apply_shock(float(data.get("duration", 4.0))); used = true
		"freeze":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true}); enemy.apply_slow(float(data.get("slow", 0.6)), float(data.get("duration", 3.0))); used = true
		"heal":
			if is_instance_valid(ally) and ally.hp < ally.max_hp:
				ally.heal(attack * power * (1.0 + passive_effect_total("healing")), self); used = true
		"hot":
			if is_instance_valid(ally) and ally.hp < ally.max_hp:
				ally.apply_hot(attack * power * (1.0 + passive_effect_total("healing")), float(data.get("duration", 6.0)), self); used = true
		"team_hot":
			var wounded := false
			for member in allied_units(int(data.get("targets", 4))):
				if member.hp < member.max_hp:
					member.apply_hot(attack * power * (1.0 + passive_effect_total("healing")), float(data.get("duration", 6.0)), self)
					wounded = true
			used = wounded
		"cleanse":
			if is_instance_valid(ally) and (ally.has_negative_status() or ally.hp < ally.max_hp):
				ally.cleanse_statuses(); ally.heal(attack * power, self); used = true
		"taunt":
			var victims: Array = battle.enemies_near(position, faction, cast_range, 12)
			if not victims.is_empty():
				for victim in victims: victim.target = self; victim.taunt_timer = float(data.get("duration", 3.5))
				add_shield(max_hp * power); used = true
		"shield":
			for member in allied_units(int(data.get("targets", 4))): member.add_shield(max_hp * power)
			used = true
		"damage_reduction":
			var members := allied_units(int(data.get("targets", 1)))
			for member in members: member.apply_damage_reduction(power, float(data.get("duration", 4.0)))
			used = true
		"damage_share":
			if is_instance_valid(ally) and ally != self and ally.hp < ally.max_hp:
				ally.apply_damage_share(self, power, float(data.get("duration", 5.0))); used = true
		"evasion":
			temporary_evasion = power; temporary_evasion_time = float(data.get("duration", 4.0)); used = true
		"counter":
			temporary_counter = power; temporary_counter_time = float(data.get("duration", 5.0)); used = true
		"move_speed":
			haste_power = power; haste_time = float(data.get("duration", 5.0)); used = true
		"cooldown":
			for member in allied_units(int(data.get("targets", 4))): member.reduce_current_cooldowns(power)
			used = true
	if not used: return false
	general_active_timers[skill_id] = effective_general_cooldown(float(data.get("cooldown", 8.0)))
	combat_event.emit("%s 施放通用技能【%s】" % [_name(), data.get("name", skill_id)])
	battle.on_skill(self)
	return true

func valid_enemy_in_range(enemy, cast_range: float) -> bool:
	return is_instance_valid(enemy) and not enemy.dead and position.distance_to(enemy.position) <= cast_range

func allied_units(limit: int) -> Array:
	var pool: Array = battle.heroes if faction == "heroes" else battle.enemies
	var result: Array = []
	for member in pool:
		if is_instance_valid(member) and not member.dead:
			result.append(member)
			if result.size() >= limit: break
	return result

func effective_general_cooldown(base_cooldown: float) -> float:
	return maxf(0.5, base_cooldown * (1.0 - cooldown_reduction))

func try_use_skill() -> bool:
	var kind: String = skill_data.get("type", "")
	var cooldown := effective_cooldown(float(skill_data.get("cooldown", 6.0)))
	var power := active_skill_power()
	match kind:
		"heal_aura":
			var ally = battle.lowest_health_ally(self)
			if ally != null and ally.hp < ally.max_hp * 0.88:
				var healing_bonus := (passive_value() if passive_data.get("effect", "") == "healing" else 0.0) + passive_effect_total("healing")
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
					victim.take_damage(attack * power * (1.0 + elemental_damage) * (1.0 - i * 0.18), self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
					battle.spawn_tracer(position if i == 0 else victims[i - 1].position, victim.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，命中 %d 个目标" % [_name(), _skill_name(), victims.size()])
				battle.on_skill(self)
				return true
		"damage":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", attack_range)):
				target.take_damage(attack * power * (1.0 + physical_damage), self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
				battle.spawn_ring(target.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				battle.on_skill(self)
				return true
		"poison":
			if is_instance_valid(target) and position.distance_to(target.position) <= float(skill_data.get("range", 210)):
				target.take_damage(attack * 0.65, self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
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
					victim.take_damage(damage, self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
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

func take_damage(raw_amount: float, source, critical: bool = false, context: Dictionary = {}) -> Dictionary:
	var result := {"raw":raw_amount, "defense":defense, "reduction":0.0, "shield_absorbed":0.0, "hp_damage":0.0, "hp_before":hp, "reason":""}
	if dead:
		result.reason = "target_dead"
		battle.record_damage_resolution(source, self, result, context)
		return result
	if not is_finite(raw_amount) or raw_amount <= 0.0:
		result.reason = "invalid_raw_damage"
		battle.record_damage_resolution(source, self, result, context)
		return result
	var evasion := passive_effect_total("evasion") + (temporary_evasion if temporary_evasion_time > 0.0 else 0.0)
	if randf() < minf(0.75, evasion):
		show_number("闪避", Color("#D4F4FF"))
		result.reason = "evaded"
		battle.record_damage_resolution(source, self, result, context)
		return result
	if damage_share_time > 0.0 and is_instance_valid(damage_share_source) and damage_share_source != self and not damage_share_source.dead:
		var shared := raw_amount * damage_share_ratio
		raw_amount -= shared
		damage_share_source.take_damage(shared, source, false, {"kind":"effect", "allow_triggers":false, "shared":true})
	var amount := float(preview_damage(raw_amount))
	var reduction_factor := 1.0
	if actor_data.get("boss_mechanic", "") == "stone_skin": reduction_factor *= 0.78
	if passive_data.get("effect", "") == "damage_reduction":
		reduction_factor *= 1.0 - clampf(passive_value(), 0.0, 0.85)
		battle.note_passive(actor_id, passive_skill_id)
	reduction_factor *= 1.0 - clampf(passive_effect_total("damage_reduction"), 0.0, 0.85)
	reduction_factor *= 1.0 - clampf(passive_effect_total("friend_guard"), 0.0, 0.85)
	if temporary_reduction_time > 0.0: reduction_factor *= 1.0 - clampf(temporary_reduction, 0.0, 0.85)
	result.reduction = 1.0 - reduction_factor
	amount = maxf(1.0, roundf(amount * reduction_factor))
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		result.shield_absorbed = absorbed
		show_number("护盾吸收 %d" % roundi(absorbed), Color("#80C8FF"))
		if shield <= 0.0 and absorbed > 0.0 and has_special("shield_burst"):
			trigger_shield_burst()
	if amount <= 0:
		result.reason = "shield_absorbed"
		battle.record_damage_resolution(source, self, result, context)
		if not battle.suppress_combat_visuals: queue_redraw()
		return result
	amount = maxf(1.0, roundf(amount))
	last_damage_source = source
	hp = maxf(0.0, hp - amount)
	result.hp_damage = amount
	result.reason = "applied"
	hit_flash = 0.12
	show_number(("暴击 -%d" if critical else "-%d") % amount, Color("#FFE26A") if critical else Color("#FF8278"))
	health_changed.emit(self)
	battle.on_damage(source, self, amount, context)
	battle.record_damage_resolution(source, self, result, context)
	if is_instance_valid(source) and source != self:
		if actor_data.get("boss_mechanic", "") == "counter_guard":
			source.take_damage(amount * 0.18, self, false, {"kind":"effect", "allow_triggers":false})
		if temporary_counter_time > 0.0:
			source.take_damage(attack * temporary_counter, self, false, {"kind":"effect", "allow_triggers":false})
		var counter_chance := passive_effect_total("counter")
		if counter_chance > 0.0 and randf() < counter_chance:
			source.take_damage(attack * 0.65, self, false, {"kind":"effect", "allow_triggers":false})
	if not battle.suppress_combat_visuals: queue_redraw()
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
	return result

func preview_damage(raw_amount: float) -> int:
	var effective_defense := defense * (1.0 - armor_break_power if armor_break_time > 0.0 else 1.0)
	return maxi(1, roundi(maxf(1.0, raw_amount - effective_defense * 0.55)))

func heal(raw_amount: float, _source, show_text: bool = true) -> void:
	var amount := mini(roundi(raw_amount), roundi(max_hp - hp))
	if amount <= 0:
		return
	hp += amount
	battle.on_heal(_source, amount)
	if show_text:
		show_number("+%d" % amount, Color("#77F09D"))
	health_changed.emit(self)
	if not battle.suppress_combat_visuals: queue_redraw()

func show_number(value: String, tint: Color) -> void:
	if battle != null and battle.suppress_combat_visuals:
		return
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

func add_shield(amount: float, duration: float = 6.0) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	shield = maxf(shield, amount)
	shield_time = maxf(shield_time, duration)
	show_number("◆ 护盾", Color("#80C8FF"))
	queue_redraw()

func apply_poison(damage_per_second: float, duration: float, source, depth: int) -> void:
	poison_damage = maxf(poison_damage, damage_per_second)
	poison_time = maxf(poison_time, duration)
	poison_source = source
	poison_depth = depth
	show_number("☠ 中毒", Color("#C58DFF"))
	queue_redraw()

func apply_burn(damage_per_second: float, duration: float, source) -> void:
	burn_damage = maxf(burn_damage, damage_per_second)
	burn_time = maxf(burn_time, duration)
	burn_source = source
	show_number("♨ 燃烧", Color("#FF9B62"))

func apply_hot(total_power: float, duration: float, source) -> void:
	hot_amount = maxf(hot_amount, total_power / maxf(1.0, duration))
	hot_time = maxf(hot_time, duration)
	hot_source = source
	show_number("✚ 持续恢复", Color("#78F0A8"))

func apply_shock(duration: float) -> void:
	shock_time = maxf(shock_time, duration)
	attack_timer += duration * 0.45
	skill_timer += duration * 0.25
	show_number("⚡ 麻痹", Color("#FFE36A"))

func apply_slow(power: float, duration: float) -> void:
	slow_power = maxf(slow_power, clampf(power, 0.0, 0.85))
	slow_time = maxf(slow_time, duration)
	show_number("❄ 减速", Color("#9DDBFF"))

func apply_armor_break(power: float, duration: float) -> void:
	armor_break_power = maxf(armor_break_power, clampf(power, 0.0, 0.8))
	armor_break_time = maxf(armor_break_time, duration)
	show_number("破甲", Color("#FFCA75"))

func apply_damage_reduction(power: float, duration: float) -> void:
	temporary_reduction = maxf(temporary_reduction, clampf(power, 0.0, 0.75))
	temporary_reduction_time = maxf(temporary_reduction_time, duration)

func apply_damage_share(source, ratio: float, duration: float) -> void:
	damage_share_source = source
	damage_share_ratio = clampf(ratio, 0.0, 0.6)
	damage_share_time = duration

func cleanse_statuses() -> void:
	poison_time = 0.0; burn_time = 0.0; slow_time = 0.0; armor_break_time = 0.0; shock_time = 0.0
	show_number("净化", Color("#F8F2C0"))

func has_negative_status() -> bool:
	return poison_time > 0.0 or burn_time > 0.0 or slow_time > 0.0 or armor_break_time > 0.0 or shock_time > 0.0

func reduce_current_cooldowns(ratio: float) -> void:
	skill_timer *= maxf(0.2, 1.0 - ratio)
	for skill_id in general_active_timers: general_active_timers[skill_id] = float(general_active_timers[skill_id]) * maxf(0.2, 1.0 - ratio)

func on_boss_skill_cast() -> void:
	match str(actor_data.get("boss_mechanic", "")):
		"shield_cycle": add_shield(max_hp * 0.08, 3.0)
		"war_banner":
			for ally in allied_units(8): ally.add_shield(max_hp * 0.04)
		"burning_aura":
			for victim in battle.enemies_near(position, faction, 210.0, 8): victim.apply_burn(attack * 0.1, 4.0, self)

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
	for row in general_passive_datas:
		var general_id: String = row.id
		var general_data: Dictionary = row.data
		var value := general_passive_value(general_id, general_data)
		match str(general_data.get("effect", "")):
			"stat_attack": attack *= 1.0 + value
			"stat_guard":
				max_hp *= 1.0 + float(general_data.get("health", 0.0)) + float(general_data.get("power_per_level", 0.0)) * (battle.progression.general_skill_level(actor_id, general_id) - 1)
				defense *= 1.0 + float(general_data.get("defense", 0.0)) + float(general_data.get("power_per_level", 0.0)) * (battle.progression.general_skill_level(actor_id, general_id) - 1)
			"attack_speed": attack_speed += value
			"cooldown_reduction": cooldown_reduction += value
			"critical": crit_chance += value
			"regeneration": life_regen += max_hp * value
			"move_speed": move_speed = float(actor_data.get("move_speed", 80)) * (1.0 + value)
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

func general_passive_value(skill_id: String, data: Dictionary) -> float:
	var level: int = battle.progression.general_skill_level(actor_id, skill_id)
	return float(data.get("power", 0.0)) + float(data.get("power_per_level", 0.0)) * (level - 1)

func passive_effect_total(effect: String) -> float:
	var total := 0.0
	for row in general_passive_datas:
		if str(row.data.get("effect", "")) == effect:
			total += general_passive_value(str(row.id), row.data)
	return total

func passive_status_mastery(status: String) -> float:
	var total := 0.0
	for row in general_passive_datas:
		if str(row.data.get("effect", "")) == "status_mastery" and str(row.data.get("status", "")) == status:
			total += general_passive_value(str(row.id), row.data)
	return total

func trigger_general_on_hit(victim) -> void:
	if not is_instance_valid(victim) or victim.dead: return
	for row in general_passive_datas:
		if str(row.data.get("effect", "")) != "on_hit_status": continue
		var chance := general_passive_value(str(row.id), row.data)
		if randf() > chance: continue
		match str(row.data.get("status", "")):
			"shock": victim.apply_shock(2.5)
			"poison": victim.apply_poison(attack * 0.12, 4.0, self, 0)
			"burn": victim.apply_burn(attack * 0.12, 4.0, self)

func on_kill_trigger() -> void:
	var power := passive_effect_total("on_kill_haste")
	if power > 0.0:
		haste_power = maxf(haste_power, power)
		haste_time = maxf(haste_time, 5.0)

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
		,"general_active": general_active_ids.duplicate()
		,"general_passive": general_passive_ids.duplicate()
	}

func _draw() -> void:
	var base := Color(actor_data.get("color", "FFFFFF"))
	var accent := _accent_color()
	if hit_flash > 0:
		base = Color.WHITE
	if actor_data.has("boss_id"):
		draw_circle(Vector2.ZERO, 34, Color(accent, 0.16))
		draw_arc(Vector2.ZERO, 34, 0, TAU, 36, accent, 4)
		draw_string(ThemeDB.fallback_font, Vector2(-28, -58), "BOSS", HORIZONTAL_ALIGNMENT_CENTER, 56, 14, Color("#FFE08A"))
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
