class_name BattleUnit
extends CharacterBody2D

const BattleMapScript = preload("res://scripts/battle_map.gd")
const FloatingTextScript = preload("res://scripts/floating_text.gd")
const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const HEALER_BASIC_ATTACK_RATIO := 0.40
const ACTIVE_HEAL_MULTIPLIER := 1.50
const HEALER_FOLLOW_RANGE_RATIO := 0.75
const HEALER_FOLLOW_TOLERANCE := 24.0
const PLAYER_RANGED_RANGE_MULTIPLIER := 2.0
const RANGED_INNER_RANGE_RATIO := 0.70
const RANGED_OUTER_RANGE_RATIO := 0.85

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
var emergency_regen := 0.0
var final_damage := 0.0
var damage_reduction := 0.0
var healing_effect := 0.0
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
var rally_timeout := 0.0
var shield := 0.0
var shield_time := 0.0
var shield_layers: Array[Dictionary] = []
var poison_damage := 0.0
var poison_time := 0.0
var poison_tick := 0.0
var poison_stack_count := 0
var poison_source
var poison_source_snapshot: Dictionary = {}
var last_damage_source
var last_damage_source_id := ""
var taunt_timer := 0.0
var control_resistance := 0.0
var accumulated_control := 0.0
var actor_level := 1
var active_skill_level := 1
var passive_skill_level := 1
var passive_skill_id := ""
var passive_data: Dictionary = {}
var basic_attack_count := 0
var consecutive_basic_count := 0
var last_basic_target_id := 0
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
var burn_source_snapshot: Dictionary = {}
var hot_amount := 0.0
var hot_time := 0.0
var hot_tick := 0.0
var hot_source
var hot_source_snapshot: Dictionary = {}
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
var temporary_attack_bonus := 0.0
var temporary_attack_bonus_time := 0.0
var attack_weaken_power := 0.0
var attack_weaken_time := 0.0
var armor_break_time := 0.0
var armor_break_power := 0.0
var shock_time := 0.0
var frost_damage := 0.0
var frost_time := 0.0
var frost_tick := 0.0
var frost_source
var frost_source_snapshot: Dictionary = {}
var home_position := Vector2.ZERO
var current_action := "idle"
var target_refresh_timer := 0.0
var rift_affixes: Array = []
var is_summon := false
var summon_owner_id := ""
var summon_lifetime := 0.0
var rescue_used_targets: Dictionary = {}
var rescue_ready_at := 0.0
var movement_strike_time := 0.0
var unstable_casts := 0
var unstable_window := 0.0
var vulnerability_time := 0.0
var vulnerability_power := 0.0
var metamorphosis_time := 0.0
var metamorphosis_cooldown := 0.0

func valid_combat_source(source):
	return source if is_instance_valid(source) else null

func combat_source_snapshot(source, fallback_damage_type: String = "none", source_skill_id: String = "") -> Dictionary:
	var snapshot := {
		"actor_id":"", "name":"环境效果", "faction":"", "damage_type":fallback_damage_type,
		"physical_damage":0.0, "elemental_damage":0.0, "final_damage":0.0,
		"source_unit_id":"", "skill_id":source_skill_id
	}
	if not is_instance_valid(source):
		return snapshot
	snapshot.source_unit_id = str(source.actor_id)
	snapshot.actor_id = str(source.summon_owner_id) if bool(source.is_summon) and not str(source.summon_owner_id).is_empty() else str(source.actor_id)
	snapshot.name = str(source._name())
	snapshot.faction = str(source.faction)
	snapshot.damage_type = str(source.actor_data.get("basic_damage_type", fallback_damage_type))
	snapshot.physical_damage = float(source.physical_damage)
	snapshot.elemental_damage = float(source.elemental_damage)
	if source.passive_skill_id == "fy_mad_blood" and source.hp / maxf(1.0, source.max_hp) <= 0.40:
		snapshot.physical_damage += float(source.passive_data.get("physical_bonus", 0.14)) + source.passive_value()
	snapshot.final_damage = float(source.final_damage) - (float(source.attack_weaken_power) if float(source.attack_weaken_time) > 0.0 else 0.0)
	if source.faction == "heroes" and is_instance_valid(source.battle) and source.battle.has_method("party_passive_value"):
		snapshot.elemental_damage += minf(0.30, source.battle.party_passive_value("team_elemental_control"))
	if snapshot.skill_id.is_empty() and bool(source.is_summon): snapshot.skill_id = "summon:" + str(source.actor_id)
	return snapshot

func setup(id: String, info: Dictionary, skill: Dictionary, team: String, owner_battle) -> void:
	actor_id = id
	actor_data = info
	skill_data = skill
	faction = team
	battle = owner_battle
	# Allies must not body-block their own formation; opposing factions still collide.
	collision_layer = 1 if team == "heroes" else 2
	collision_mask = 2 if team == "heroes" else 1
	if team == "heroes" and battle.progression != null and not bool(info.get("summoned", false)):
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
	rift_affixes = info.get("rift_affixes", []).duplicate()
	base_max_hp = float(info.get("max_hp", 100)) * (1.0 + (actor_level - 1) * 0.08)
	base_attack = float(info.get("attack", 10)) * (1.0 + (actor_level - 1) * 0.06)
	base_defense = float(info.get("defense", 0)) * (1.0 + (actor_level - 1) * 0.05)
	base_attack_interval = float(info.get("attack_interval", 1.0))
	max_hp = base_max_hp
	hp = max_hp
	attack = base_attack
	defense = base_defense
	move_speed = float(info.get("move_speed", 80))
	attack_range = resolved_attack_range()
	attack_interval = base_attack_interval
	if "swift" in rift_affixes:
		move_speed *= 1.22; attack_interval *= 0.82
	if "iron_wall" in rift_affixes:
		defense *= 1.18
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
	if is_summon:
		summon_lifetime -= delta
		if summon_lifetime <= 0.0:
			dead = true; battle.heroes.erase(self); queue_free(); return
	attack_timer = maxf(0.0, attack_timer - delta)
	skill_timer = maxf(0.0, skill_timer - delta)
	for general_id in general_active_timers:
		general_active_timers[general_id] = maxf(0.0, float(general_active_timers[general_id]) - delta)
	target_refresh_timer = maxf(0.0, target_refresh_timer - delta)
	rally_timeout = maxf(0.0, rally_timeout - delta)
	repath_timer -= delta
	hit_flash = maxf(0.0, hit_flash - delta)
	taunt_timer = maxf(0.0, taunt_timer - delta)
	temporary_reduction_time = maxf(0.0, temporary_reduction_time - delta)
	if shield_time > 0.0:
		shield_time = maxf(0.0, shield_time - delta)
		if shield_time <= 0.0 and shield > 0.0:
			shield = 0.0
			shield_layers.clear()
			show_number("护盾消散", Color("#A8D9FF"))
			queue_redraw()
	temporary_evasion_time = maxf(0.0, temporary_evasion_time - delta)
	temporary_counter_time = maxf(0.0, temporary_counter_time - delta)
	damage_share_time = maxf(0.0, damage_share_time - delta)
	haste_time = maxf(0.0, haste_time - delta)
	temporary_attack_bonus_time = maxf(0.0, temporary_attack_bonus_time - delta)
	if temporary_attack_bonus_time <= 0.0: temporary_attack_bonus = 0.0
	attack_weaken_time = maxf(0.0, attack_weaken_time - delta)
	if attack_weaken_time <= 0.0: attack_weaken_power = 0.0
	slow_time = maxf(0.0, slow_time - delta)
	armor_break_time = maxf(0.0, armor_break_time - delta)
	shock_time = maxf(0.0, shock_time - delta)
	movement_strike_time = maxf(0.0, movement_strike_time - delta)
	unstable_window = maxf(0.0, unstable_window - delta)
	if unstable_window <= 0.0: unstable_casts = 0
	vulnerability_time = maxf(0.0, vulnerability_time - delta)
	metamorphosis_time = maxf(0.0, metamorphosis_time - delta)
	metamorphosis_cooldown = maxf(0.0, metamorphosis_cooldown - delta)
	if passive_skill_id == "wow_metamorphosis" and hp / maxf(1.0, max_hp) <= 0.40 and metamorphosis_time <= 0.0 and metamorphosis_cooldown <= 0.0:
		metamorphosis_time = 7.0
		metamorphosis_cooldown = 18.0
	elif passive_skill_id == "naruto_sage_affinity" and hp / maxf(1.0, max_hp) <= 0.85 and metamorphosis_time <= 0.0 and metamorphosis_cooldown <= 0.0 and is_instance_valid(battle.find_closest_enemy(self)):
		metamorphosis_time = 7.0
		metamorphosis_cooldown = 18.0
		battle.note_passive(actor_id, passive_skill_id)
		show_number("仙人模式", Color("#E8B85A"))
	if poison_time > 0.0:
		poison_time -= delta
		poison_tick += delta
		if poison_tick >= 1.0:
			poison_tick -= 1.0
			take_damage(poison_damage, valid_combat_source(poison_source), false, {"kind": "effect", "damage_type": "elemental", "allow_triggers": false, "poison": true, "source_snapshot":poison_source_snapshot})
		if poison_time <= 0.0: poison_stack_count = 0
	if burn_time > 0.0:
		burn_time -= delta
		burn_tick += delta
		if burn_tick >= 1.0:
			burn_tick -= 1.0
			take_damage(burn_damage, valid_combat_source(burn_source), false, {"kind": "effect", "damage_type": "elemental", "allow_triggers": false, "burn": true, "source_snapshot":burn_source_snapshot})
	if hot_time > 0.0:
		hot_time -= delta
		hot_tick += delta
		if hot_tick >= 1.0:
			hot_tick -= 1.0
			heal(hot_amount, valid_combat_source(hot_source), false, {"source_snapshot":hot_source_snapshot})
	if frost_time > 0.0:
		frost_time -= delta
		frost_tick += delta
		if frost_tick >= 1.0:
			frost_tick -= 1.0
			take_damage(frost_damage, valid_combat_source(frost_source), false, {"kind":"effect", "damage_type":"elemental", "allow_triggers":false, "frost":true, "source_snapshot":frost_source_snapshot})
	var current_regen := life_regen + (emergency_regen if hp / maxf(1.0, max_hp) <= 0.35 else 0.0)
	if current_regen > 0.0 and hp < max_hp:
		regen_accumulator += delta
		if regen_accumulator >= 1.0:
			regen_accumulator -= 1.0
			heal(current_regen, self, false)
	if not is_instance_valid(target) or target.dead:
		target = null
	if faction == "heroes" and taunt_timer <= 0.0 and target_refresh_timer <= 0.0:
		target = battle.select_combat_target(self)
		target_refresh_timer = 0.65
	if has_rally:
		# A rally order is a short reposition command, not a permanent combat lock.
		# Nearby threats immediately return control to normal role AI.
		var threat_in_range := is_instance_valid(target) and position.distance_to(target.position) <= attack_range
		if position.distance_to(rally_target) < 22.0 or rally_timeout <= 0.0 or threat_in_range:
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
	if is_player_ranged():
		var configured_safe := float(actor_data.get("minimum_safe_distance", float(actor_data.get("attack_range", 60.0)) * RANGED_INNER_RANGE_RATIO))
		var minimum_safe := maxf(effective_cast_range(configured_safe), attack_range * RANGED_INNER_RANGE_RATIO)
		minimum_safe = maxf(minimum_safe, boss_aoe_safe_distance(target))
		if distance <= attack_range:
			if try_auto_skills(): return
			# Fire before repositioning. This prevents ranged heroes from spending
			# every ready frame retreating without ever performing a basic attack.
			if attack_timer <= 0.0:
				basic_attack()
				return
			var retreat_limit := minimum_safe + (18.0 if current_action == "retreat" else 0.0)
			if distance < retreat_limit:
				current_action = "retreat"
				move_away_from_point(target.position)
			elif distance > attack_range * RANGED_OUTER_RANGE_RATIO:
				# Re-form into the preferred 70%-85% band after firing. The wide
				# hysteresis prevents approach/retreat oscillation at its edges.
				current_action = "seek_firing_position"
				move_toward_point(target.position, delta)
			else:
				velocity = Vector2.ZERO
				current_action = "hold_range"
			return
		if try_auto_skills(): return
		current_action = "seek_firing_position"
		# Outside attack range, pursue the live target directly. Preferred spacing
		# resumes after entering range, avoiding boundary-seeking deadlocks.
		move_toward_point(target.position, delta)
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
	var clamped_point := Vector2(
		clampf(point.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0),
		clampf(point.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	)
	nav_goal = clamped_point
	var direction := position.direction_to(clamped_point)
	var speed_factor := (1.0 + haste_power if haste_time > 0.0 else 1.0) * (1.0 - slow_power if slow_time > 0.0 else 1.0)
	velocity = direction * move_speed * maxf(0.15, speed_factor)
	if absf(direction.x) > 0.05:
		facing = signf(direction.x)
	move_and_slide()
	if passive_skill_id == "ninja_shadow" and velocity.length_squared() > 1.0:
		movement_strike_time = 2.5
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
	var configured_safe := float(actor_data.get("minimum_safe_distance", float(actor_data.get("attack_range", 60.0)) * RANGED_INNER_RANGE_RATIO))
	var minimum_safe := maxf(effective_cast_range(configured_safe), attack_range * RANGED_INNER_RANGE_RATIO)
	minimum_safe = maxf(minimum_safe, boss_aoe_safe_distance(danger))
	if is_instance_valid(danger) and position.distance_to(danger.position) < minimum_safe:
		current_action = "retreat"
		var retreat_point := healer_follow_point(healer_anchor(), danger)
		move_toward_point(retreat_point, delta)
		return
	var ally = battle.lowest_health_ally(self, 9999.0)
	if ally != null and ally.hp < ally.max_hp * 0.995:
		target = ally
		if try_auto_skills():
			return
		if position.distance_to(ally.position) <= attack_range:
			if attack_timer <= 0.0:
				basic_attack()
			else:
				current_action = "heal_ready"
				velocity = Vector2.ZERO
			return
		current_action = "seek_heal_range"
		var heal_direction: Vector2 = ally.position.direction_to(position)
		if heal_direction.length_squared() < 0.01: heal_direction = Vector2.LEFT
		move_toward_point(ally.position + heal_direction * attack_range * 0.72, delta)
		return
	target = null
	var anchor = healer_anchor()
	if anchor == null:
		return_to_formation(delta)
		return
	var follow_point := healer_follow_point(anchor, danger)
	if position.distance_to(follow_point) > HEALER_FOLLOW_TOLERANCE:
		current_action = "follow_tank"
		move_toward_point(follow_point, delta)
	else:
		current_action = "healer_cover"
		velocity = Vector2.ZERO

func healer_anchor():
	var alive: Array = []
	for member in battle.heroes:
		if is_instance_valid(member) and not member.dead and member != self and not member.is_summon:
			alive.append(member)
	if alive.is_empty(): return null
	var candidates := alive.filter(func(member): return str(member.actor_data.get("combat_role", "")) == "tank")
	if candidates.is_empty():
		candidates = alive.filter(func(member): return str(member.actor_data.get("combat_style", "")) == "melee")
	if candidates.is_empty():
		# No frontliner: use the living party member nearest the team centre.
		var centre := Vector2.ZERO
		for member in alive: centre += member.position
		centre /= alive.size()
		candidates = alive.duplicate()
		candidates.sort_custom(func(a, b): return a.position.distance_squared_to(centre) < b.position.distance_squared_to(centre))
		return candidates[0]
	# The main tank is the candidate currently closest to enemy pressure.
	candidates.sort_custom(func(a, b):
		var enemy_a = battle.find_closest_enemy(a)
		var enemy_b = battle.find_closest_enemy(b)
		var distance_a: float = a.position.distance_squared_to(enemy_a.position) if is_instance_valid(enemy_a) else -a.position.x
		var distance_b: float = b.position.distance_squared_to(enemy_b.position) if is_instance_valid(enemy_b) else -b.position.x
		return distance_a < distance_b
	)
	return candidates[0]

func healer_follow_point(anchor, danger = null) -> Vector2:
	if anchor == null: return home_position
	var threat = danger if is_instance_valid(danger) else battle.find_closest_enemy(anchor)
	var away := Vector2.LEFT
	if is_instance_valid(threat):
		away = threat.position.direction_to(anchor.position)
	if away.length_squared() < 0.01: away = Vector2.LEFT
	var desired: Vector2 = anchor.position + away.normalized() * attack_range * HEALER_FOLLOW_RANGE_RATIO
	desired.x = clampf(desired.x, 24.0, BattleMapScript.ARENA_SIZE.x - 24.0)
	desired.y = clampf(desired.y, 34.0, BattleMapScript.ARENA_SIZE.y - 24.0)
	return desired

func is_player_ranged() -> bool:
	var style := str(actor_data.get("combat_style", "melee"))
	return faction == "heroes" and not bool(actor_data.get("summoned", false)) and (style in ["ranged", "healer"] or str(actor_data.get("basic_action", "damage")) == "heal")

func resolved_attack_range() -> float:
	var configured := float(actor_data.get("attack_range", 60.0))
	return configured * PLAYER_RANGED_RANGE_MULTIPLIER if is_player_ranged() else configured

func effective_cast_range(configured_range: float) -> float:
	return configured_range * PLAYER_RANGED_RANGE_MULTIPLIER if is_player_ranged() else configured_range

func boss_aoe_safe_distance(enemy) -> float:
	if not is_instance_valid(enemy) or not enemy.actor_data.has("boss_id"):
		return 0.0
	var kind := str(enemy.skill_data.get("type", ""))
	if kind not in ["area_damage", "boss_area", "area_control", "burn_area", "gravity_taunt", "taunt"]:
		return 0.0
	# Keep a small collision margin outside the configured boss effect radius.
	# This only influences movement and never changes the boss skill itself.
	return minf(float(enemy.skill_data.get("range", 0.0)) + 28.0, attack_range * RANGED_OUTER_RANGE_RATIO)

func basic_attack() -> void:
	attack_timer = attack_interval / (1.0 + haste_power if haste_time > 0.0 else 1.0)
	if passive_skill_id == "fy_mad_blood" and hp / maxf(1.0, max_hp) <= 0.40:
		attack_timer /= 1.0 + passive_value()
	current_action = "basic_attack"
	if actor_data.get("basic_action", "damage") == "heal" and is_instance_valid(target) and target.faction == faction:
		var healing_bonus := (passive_value() if passive_data.get("effect", "") == "healing" else 0.0) + passive_effect_total("healing")
		target.heal(basic_heal_amount(attack * HEALER_BASIC_ATTACK_RATIO * (1.0 + healing_bonus)), self, true, {"source_snapshot":combat_source_snapshot(self, "none", "basic_heal")})
		if healing_bonus > 0.0:
			battle.note_passive(actor_id, passive_skill_id)
		battle.spawn_tracer(position, target.position, Color("#78F0A8"))
		return
	var amount := attack * randf_range(0.9, 1.1)
	if passive_skill_id == "ninja_shadow" and movement_strike_time > 0.0:
		amount *= 1.0 + passive_value()
		movement_strike_time = 0.0
		battle.note_passive(actor_id, passive_skill_id)
	if passive_skill_id == "wow_metamorphosis" and metamorphosis_time > 0.0:
		amount *= 1.0 + passive_value()
	if passive_data.get("effect", "") == "low_hp_rage" and hp / max_hp < 0.4:
		amount *= 1.0 + passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if passive_data.get("effect", "") == "boss_slayer" and target.actor_data.has("boss_id"):
		amount *= 1.0 + passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if passive_data.get("effect", "") == "execute_damage" and target.hp / maxf(1.0, target.max_hp) <= 0.35:
		amount *= 1.0 + passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if passive_data.get("effect", "") == "burn_master" and target.burn_time > 0.0:
		amount *= 1.0 + passive_value() * 0.65
		battle.note_passive(actor_id, passive_skill_id)
	if passive_data.get("effect", "") == "armor_ignore":
		amount += target.defense * 0.55 * passive_value()
		battle.note_passive(actor_id, passive_skill_id)
	if actor_data.get("boss_id", "") == "lu_bu" and hp / max_hp < 0.5:
		amount *= 1.45
	if actor_data.get("boss_mechanic", "") == "berserk" and hp / max_hp < 0.5:
		amount *= 1.35
	var conditional_crit := passive_value() if passive_skill_id == "hunting_instinct" and target.armor_break_time > 0.0 else 0.0
	var critical := randf() < minf(0.75, crit_chance + conditional_crit)
	if critical:
		amount *= crit_damage
		if passive_skill_id == "hy_golden_core":
			haste_power = maxf(haste_power, passive_value())
			haste_time = maxf(haste_time, 4.0)
			battle.note_passive(actor_id, passive_skill_id)
	if target.has_negative_status(): amount *= 1.0 + passive_effect_total("status_amplifier") + (passive_value() if passive_data.get("effect", "") == "status_amplifier" else 0.0)
	var current_target_id: int = target.get_instance_id()
	consecutive_basic_count = consecutive_basic_count + 1 if current_target_id == last_basic_target_id else 1
	last_basic_target_id = current_target_id
	var next_basic_count := basic_attack_count + 1
	if consecutive_basic_count % 3 == 0: amount *= 1.0 + passive_effect_total("combo")
	if has_general_passive("jy_jade_maiden") and consecutive_basic_count % 4 == 0:
		amount *= 1.0 + general_passive_by_id("jy_jade_maiden")
	target.take_damage(amount, self, critical, {"kind": "basic", "damage_type": str(actor_data.get("basic_damage_type", "physical")), "critical": critical, "allow_triggers": true})
	match str(actor_data.get("boss_mechanic", "")):
		"venom_strike": target.apply_poison(attack * 0.12, 4.0, self)
		"shock_strike": target.apply_shock(2.2)
		"regeneration": heal(amount * 0.16, self, false)
	if "venom" in rift_affixes: target.apply_poison(attack * 0.10, 4.0, self)
	trigger_general_on_hit(target)
	basic_attack_count = next_basic_count
	if passive_data.get("effect", "") == "combo" and basic_attack_count % 3 == 0 and is_instance_valid(target) and not target.dead:
		target.take_damage(attack * passive_value(), self, false, {"kind": "passive", "damage_type":"elemental" if passive_skill_id == "wow_windfury_weapon" else str(actor_data.get("basic_damage_type", "physical")), "allow_triggers": true})
		battle.note_passive(actor_id, passive_skill_id)
	if passive_skill_id == "hyper_perception" and is_instance_valid(target):
		for member in allied_units(4):
			if member != self and (target.enemy_type in ["elite", "boss"] or target.attack >= attack): member.target = target
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
	var cast_range := effective_cast_range(float(data.get("range", maxf(float(actor_data.get("attack_range", 60.0)), 180.0))))
	var enemy = battle.find_closest_enemy(self)
	var ally = battle.lowest_health_ally(self, cast_range)
	var used := false
	match str(data.get("effect", "")):
		"damage":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"stun":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				enemy.apply_hard_control(float(data.get("duration", 1.2)))
				if data.has("armor_break"): enemy.apply_armor_break(minf(0.8, float(data.armor_break) * armor_break_multiplier()), maxf(4.0, float(data.get("duration", 1.2))))
				used = true
		"low_hp_damage":
			if valid_enemy_in_range(enemy, cast_range):
				var low_hp_multiplier := 1.65 if hp / maxf(1.0, max_hp) <= 0.4 else 1.0
				enemy.take_damage(attack * power * low_hp_multiplier, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"leech_damage":
			if valid_enemy_in_range(enemy, cast_range):
				var dealt := attack * power
				enemy.take_damage(dealt, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				heal(active_heal_amount(dealt * clampf(float(data.get("leech", 0.12)), 0.0, 0.20)), self, false)
				used = true
		"self_cost_damage":
			if valid_enemy_in_range(enemy, cast_range) and hp > max_hp * 0.18:
				hp = maxf(1.0, hp - max_hp * clampf(float(data.get("health_cost", 0.06)), 0.0, 0.10))
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"multi_hit":
			if valid_enemy_in_range(enemy, cast_range):
				var bonus := 1.0 + passive_effect_total("multi_hit_bonus")
				for _hit in range(int(data.get("hits", 3))): enemy.take_damage(attack * power * bonus, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true, "multi_hit":true})
				used = true
		"evasion_strike":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				temporary_evasion = maxf(temporary_evasion, float(data.get("evasion", 0.20)))
				temporary_evasion_time = maxf(temporary_evasion_time, float(data.get("duration", 4.0)))
				used = true
		"multi_hit_knockback":
			if valid_enemy_in_range(enemy, cast_range):
				for _hit in range(int(data.get("hits", 4))): enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true, "multi_hit":true})
				var push_direction: Vector2 = position.direction_to(enemy.position)
				var pushed: Vector2 = enemy.position + push_direction * float(data.get("knockback", 48.0))
				pushed.x = clampf(pushed.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
				pushed.y = clampf(pushed.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
				if not battle.point_blocked(pushed): enemy.position = pushed
				used = true
		"multi_hit_armor_break":
			if valid_enemy_in_range(enemy, cast_range):
				for _hit in range(int(data.get("hits", 3))): enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true, "multi_hit":true})
				enemy.apply_armor_break(minf(0.8, float(data.get("armor_break", 0.23)) * armor_break_multiplier()), float(data.get("duration", 5.0)))
				used = true
		"area_damage":
			if valid_enemy_in_range(enemy, cast_range):
				var area_origin: Vector2 = position if skill_id == "wow_blade_storm" else enemy.position
				for victim in battle.enemies_near(area_origin, faction, 125.0, 6): victim.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				battle.spawn_ring(area_origin, Color("#F2C66D")); used = true
		"area_slow_damage":
			if valid_enemy_in_range(enemy, cast_range):
				for victim in battle.enemies_near(enemy.position, faction, 135.0, 8):
					victim.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
					victim.apply_slow(float(data.get("slow", 0.32)), float(data.get("duration", 4.0)))
				used = true
		"area_knockback":
			if valid_enemy_in_range(enemy, cast_range):
				for victim in battle.enemies_near(enemy.position, faction, 130.0, 8):
					victim.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
					var direction: Vector2 = enemy.position.direction_to(victim.position)
					if direction.length_squared() < 0.01: direction = position.direction_to(victim.position)
					var destination: Vector2 = victim.position + direction.normalized() * float(data.get("knockback", 46.0))
					destination.x = clampf(destination.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0)
					destination.y = clampf(destination.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
					if not battle.point_blocked(destination): victim.position = destination
				used = true
		"vulnerability_strike":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				enemy.vulnerability_power = maxf(enemy.vulnerability_power, float(data.get("vulnerability", 0.18)))
				enemy.vulnerability_time = maxf(enemy.vulnerability_time, float(data.get("duration", 5.0)))
				used = true
		"chain":
			if valid_enemy_in_range(enemy, cast_range):
				var victims: Array = battle.enemies_near(enemy.position, faction, 190.0, int(data.get("targets", 4)))
				if skill_id == "nh_spear_break":
					var direction := position.direction_to(enemy.position)
					victims = battle.enemies_near(position, faction, cast_range, 12).filter(func(candidate): return absf(direction.cross(position.direction_to(candidate.position))) <= 0.28)
					victims.sort_custom(func(a, b): return position.distance_squared_to(a.position) < position.distance_squared_to(b.position))
					victims = victims.slice(0, int(data.get("targets", 4)))
				for index in range(victims.size()): victims[index].take_damage(attack * power * (1.0 - index * 0.12), self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				used = true
		"armor_break":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
				enemy.apply_armor_break(minf(0.8, float(data.get("armor_break", 0.25)) * armor_break_multiplier()), float(data.get("duration", 5.0)))
				if skill_id == "dz_alchemy_seal" and enemy.shield > 0.0: enemy.shield *= 1.0 - minf(0.45, float(data.get("armor_break", 0.25)))
				used = true
		"burn", "poison":
			if valid_enemy_in_range(enemy, cast_range):
				var mastery := 1.0 + passive_status_mastery(str(data.effect))
				var status_targets: Array = battle.enemies_near(enemy.position, faction, 115.0, 6) if skill_id == "dz_dragon_flame" else [enemy]
				for status_target in status_targets:
					status_target.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
					if data.effect == "burn": status_target.apply_burn(attack * float(data.get("dot_power", 0.18)) * mastery, float(data.get("duration", 5.0)) * mastery, self, combat_source_snapshot(self, "elemental", skill_id))
					else:
						if skill_id == "pk_toxic": status_target.poison_stack_count = mini(3, status_target.poison_stack_count + 1)
						var stack_power: float = 1.0 + 0.25 * maxf(0.0, status_target.poison_stack_count - 1) if skill_id == "pk_toxic" else 1.0
						status_target.apply_poison(attack * float(data.get("dot_power", 0.18)) * mastery * stack_power, float(data.get("duration", 6.0)) * mastery, self, combat_source_snapshot(self, "elemental", skill_id))
				used = true
		"shock":
			if valid_enemy_in_range(enemy, cast_range):
				enemy.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true}); enemy.apply_shock(float(data.get("duration", 4.0))); used = true
		"area_shock":
			if valid_enemy_in_range(enemy, cast_range):
				for victim in battle.enemies_near(enemy.position, faction, 125.0, 8):
					victim.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true})
					victim.apply_shock(float(data.get("duration", 3.0)))
				used = true
		"freeze":
			if valid_enemy_in_range(enemy, cast_range):
				var freeze_mastery := 1.0 + passive_status_mastery("freeze")
				var freeze_targets: Array = battle.enemies_near(enemy.position, faction, 120.0, 6) if skill_id == "nh_cold_resonance" else [enemy]
				for freeze_target in freeze_targets:
					freeze_target.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":skill_id, "allow_triggers":true}); freeze_target.apply_slow(minf(0.8, float(data.get("slow", 0.6)) * freeze_mastery), minf(7.0, float(data.get("duration", 3.0)) * freeze_mastery))
				used = true
		"heal":
			if is_instance_valid(ally) and ally.hp < ally.max_hp:
				ally.heal(active_heal_amount(attack * power * (1.0 + passive_effect_total("healing"))), self, true, {"source_snapshot":combat_source_snapshot(self, "none", skill_id)}); used = true
		"hot":
			if is_instance_valid(ally) and ally.hp < ally.max_hp:
				ally.apply_hot(active_heal_amount(attack * power * (1.0 + passive_effect_total("healing"))), float(data.get("duration", 6.0)), self, combat_source_snapshot(self, "none", skill_id + ":hot")); used = true
		"team_hot":
			var wounded := false
			for member in allied_units(int(data.get("targets", 4))):
				if member.hp < member.max_hp:
					member.apply_hot(active_heal_amount(attack * power * (1.0 + passive_effect_total("healing"))), float(data.get("duration", 6.0)), self, combat_source_snapshot(self, "none", skill_id + ":hot"))
					wounded = true
			used = wounded
		"cleanse":
			if is_instance_valid(ally) and (ally.has_negative_status() or ally.hp < ally.max_hp):
				ally.cleanse_statuses(); ally.heal(active_heal_amount(attack * power), self, true, {"source_snapshot":combat_source_snapshot(self, "none", skill_id)}); used = true
		"taunt":
			var victims: Array = battle.enemies_near(position, faction, cast_range, 12)
			if not victims.is_empty():
				for victim in victims: victim.target = self; victim.taunt_timer = float(data.get("duration", 3.5))
				add_shield(max_hp * power * shield_power_multiplier(), 6.0, self, skill_id); used = true
		"shield":
			var shield_bonus := 1.0 + passive_effect_total("shield_power")
			var shield_targets := allied_units(8)
			shield_targets.sort_custom(func(a, b): return a.hp / maxf(1.0, a.max_hp) < b.hp / maxf(1.0, b.max_hp))
			for member in shield_targets.slice(0, int(data.get("targets", 4))): member.add_shield(max_hp * power * shield_bonus, 6.0, self, skill_id)
			used = true
		"damage_reduction":
			var members := [self] if int(data.get("targets", 1)) == 1 else allied_units(8)
			if int(data.get("targets", 1)) > 1:
				members.sort_custom(func(a, b): return (0 if str(a.actor_data.get("combat_role", "")) == "tank" else 1 if str(a.actor_data.get("combat_style", "")) == "melee" else 2) < (0 if str(b.actor_data.get("combat_role", "")) == "tank" else 1 if str(b.actor_data.get("combat_style", "")) == "melee" else 2))
				members = members.slice(0, int(data.get("targets", 1)))
			for member in members: member.apply_damage_reduction(power, float(data.get("duration", 4.0)))
			used = true
		"damage_share":
			if is_instance_valid(ally) and ally != self and ally.hp < ally.max_hp:
				ally.apply_damage_share(self, power, float(data.get("duration", 5.0))); used = true
		"evasion":
			temporary_evasion = power; temporary_evasion_time = float(data.get("duration", 4.0)); used = true
			if skill_id == "nh_wave_shadow": haste_power = maxf(haste_power, power); haste_time = maxf(haste_time, float(data.get("duration", 5.0)))
		"counter":
			temporary_counter = power; temporary_counter_time = float(data.get("duration", 5.0)); used = true
		"move_speed":
			haste_power = power; haste_time = float(data.get("duration", 5.0)); used = true
		"cooldown":
			for member in allied_units(int(data.get("targets", 4))):
				member.reduce_current_cooldowns(power)
				if skill_id == "wow_battle_shout": member.haste_power = maxf(member.haste_power, power); member.haste_time = maxf(member.haste_time, 5.0)
			used = true
		"blood_boost":
			var cost := max_hp * float(data.get("health_cost", 0.08))
			hp = maxf(1.0, hp - cost)
			temporary_attack_bonus = power; temporary_attack_bonus_time = float(data.get("duration", 6.0)); haste_power = power * 0.5; haste_time = float(data.get("duration", 6.0)); used = true
		"summon_clone":
			var clone_count := 0
			var clone_pool: Array = battle.heroes if faction == "heroes" else battle.enemies
			for member in clone_pool:
				if is_instance_valid(member) and member.is_summon and member.summon_owner_id == actor_id and member.actor_id == "naruto_shadow_clone_unit": clone_count += 1
			if clone_count < int(data.get("summon_cap", 1)):
				var group := "heroes" if faction == "heroes" else "enemies"
				var clone = battle.spawn_unit("naruto_shadow_clone_unit", group, position + Vector2(34, 24), {"summoned":true})
				clone.is_summon = true; clone.summon_owner_id = actor_id; clone.summon_lifetime = float(data.get("duration", 9.0)); clone.max_hp = max_hp * 0.25; clone.hp = clone.max_hp; clone.attack = attack * power; clone.defense = defense * 0.35
				used = true
	if not used: return false
	var echo_chance := passive_effect_total("skill_echo")
	if echo_chance > 0.0 and randf() < echo_chance and is_instance_valid(enemy):
		enemy.take_damage(attack * 0.35, self, false, {"kind":"effect","allow_triggers":false,"skill_echo":true})
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
				ally.heal(active_heal_amount(attack * power * (1.0 + healing_bonus)), self, true, {"source_snapshot":combat_source_snapshot(self, "none", str(actor_data.get("skill", "")))})
				ally.add_shield(attack * (1.0 + healing_bonus) * shield_power_multiplier(), 6.0, self, str(actor_data.get("skill", "")))
				if healing_bonus > 0.0: battle.note_passive(actor_id, passive_skill_id)
				battle.spawn_ring(ally.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，治疗 %s" % [_name(), _skill_name(), ally._name()])
				battle.on_skill(self)
				return true
		"self_heal":
			if hp < max_hp * 0.72:
				heal(active_heal_amount(max_hp * power), self, true, {"source_snapshot":combat_source_snapshot(self, "none", str(actor_data.get("skill", "")))})
				battle.spawn_ring(position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】恢复体力" % [_name(), _skill_name()])
				battle.on_skill(self)
				return true
		"chain":
			if is_instance_valid(target) and position.distance_to(target.position) <= effective_cast_range(float(skill_data.get("range", 220))):
				var victims: Array = battle.enemies_near(target.position, faction, 145.0, 3)
				for i in range(victims.size()):
					var victim = victims[i]
					victim.take_damage(attack * power * (1.0 - i * 0.18), self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
					battle.spawn_tracer(position if i == 0 else victims[i - 1].position, victim.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】，命中 %d 个目标" % [_name(), _skill_name(), victims.size()])
				battle.on_skill(self)
				return true
		"damage":
			if is_instance_valid(target) and position.distance_to(target.position) <= effective_cast_range(float(skill_data.get("range", float(actor_data.get("attack_range", 60.0))))):
				var damage := attack * power
				if str(actor_data.get("skill", "")) == "spear_flurry":
					var advance := maxf(0.0, minf(68.0, position.distance_to(target.position) - 28.0))
					var destination := position.move_toward(target.position, advance)
					if not battle.point_blocked(destination): position = destination
				elif str(actor_data.get("skill", "")) == "blood_rage" and hp / maxf(1.0, max_hp) <= 0.40:
					damage *= 1.45
				target.take_damage(damage, self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
				battle.spawn_ring(target.position, _skill_color())
				skill_timer = cooldown
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				battle.on_skill(self)
				return true
		"poison":
			if is_instance_valid(target) and position.distance_to(target.position) <= effective_cast_range(float(skill_data.get("range", 210))):
				target.take_damage(attack * 0.65, self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
				var poison_bonus := passive_value() if passive_data.get("effect", "") == "poison_master" else 0.0
				target.apply_poison(attack * power * (1.0 + poison_bonus), float(skill_data.get("duration", 6.0)) * (1.0 + poison_bonus * 0.5), self, combat_source_snapshot(self, "elemental", str(actor_data.get("skill", ""))))
				if poison_bonus > 0.0: battle.note_passive(actor_id, passive_skill_id)
				skill_timer = cooldown
				battle.on_skill(self)
				combat_event.emit("%s 施放【%s】，目标中毒" % [_name(), _skill_name()])
				return true
		"area_damage", "boss_area":
			var area_center: Vector2 = target.position if str(actor_data.get("skill", "")) == "psycho_burst" and is_instance_valid(target) else position
			if str(actor_data.get("skill", "")) == "psycho_burst" and (not is_instance_valid(target) or position.distance_to(target.position) > effective_cast_range(float(skill_data.get("range", 170)))): return false
			var victims: Array = battle.enemies_near(area_center, faction, 125.0 if str(actor_data.get("skill", "")) == "psycho_burst" else float(skill_data.get("range", 170)), 12)
			if not victims.is_empty():
				for victim in victims:
					var damage := attack * power
					if actor_data.get("boss_mechanic", "") == "dragon_king_phases":
						if hp / maxf(1.0, max_hp) <= 0.65: damage *= 1.18; add_shield(max_hp * 0.06, 4.0)
						if hp / maxf(1.0, max_hp) <= 0.30: damage *= 1.28; haste_power = 0.25; haste_time = 6.0
					elif actor_data.get("boss_mechanic", "") == "star_sword_phases" and hp / maxf(1.0, max_hp) <= 0.5:
						damage *= 1.24; victim.apply_slow(0.22, 3.0)
					elif actor_data.get("boss_mechanic", "") == "final_burst_phases":
						if hp / maxf(1.0, max_hp) <= 0.55: damage *= 1.18; haste_power = 0.16; haste_time = 5.0
						if hp / maxf(1.0, max_hp) <= 0.25: damage *= 1.24; temporary_evasion = 0.10; temporary_evasion_time = 3.0
					if passive_data.get("effect", "") == "boss_slayer" and victim.actor_data.has("boss_id"):
						damage *= 1.0 + passive_value()
						battle.note_passive(actor_id, passive_skill_id)
					victim.take_damage(damage, self, false, {"kind": "skill", "skill_id":str(actor_data.get("skill", "")), "allow_triggers": true})
				if actor_data.get("boss_id", "") == "mewtwo":
					add_shield(max_hp * 0.12)
				skill_timer = cooldown
				if actor_data.has("boss_id"): on_boss_skill_cast()
				battle.on_skill(self)
				combat_event.emit("%s 施放【%s】" % [_name(), _skill_name()])
				return true
		"area_control":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 245.0)))):
				var victims: Array = battle.enemies_near(target.position, faction, 135.0, 8)
				var control_multiplier := 1.0 + (float(passive_data.get("control_bonus", 0.0)) if passive_skill_id == "fy_holy_sword_intent" else 0.0)
				for victim in victims:
					victim.take_damage(attack * power, self, false, {"kind":"skill", "skill_id":actor_data.skill, "allow_triggers":true})
					victim.apply_hard_control(float(skill_data.get("duration", 1.2)) * control_multiplier)
				skill_timer = cooldown; battle.on_skill(self); return true
		"taunt":
			var victims: Array = battle.enemies_near(position, faction, float(skill_data.get("range", 230)), 12)
			for victim in victims:
				victim.target = self
				victim.taunt_timer = float(skill_data.get("duration", 3.0))
			add_shield(max_hp * power * shield_power_multiplier())
			apply_damage_reduction(float(skill_data.get("damage_reduction", 0.22)), float(skill_data.get("duration", 3.0)))
			skill_timer = cooldown
			battle.on_skill(self)
			return true
		"team_haste":
			var allies: Array = battle.heroes if faction == "heroes" else battle.enemies
			for ally in allies:
				if is_instance_valid(ally):
					ally.skill_timer *= maxf(0.35, 1.0 - power)
					if str(actor_data.get("skill", "")) == "wow_bloodlust":
						ally.haste_power = maxf(ally.haste_power, power)
						ally.haste_time = maxf(ally.haste_time, float(skill_data.get("duration", 6.0)))
			skill_timer = cooldown
			battle.on_skill(self)
			return true
		"execute_cone":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 125.0)))):
				var victims: Array = battle.enemies_near(target.position, faction, 95.0, 5)
				for victim in victims:
					var damage := attack * power
					if victim.hp / maxf(1.0, victim.max_hp) <= 0.35: damage *= 1.55
					if passive_data.get("effect", "") == "execute_damage" and victim.hp / maxf(1.0, victim.max_hp) <= 0.35:
						damage *= 1.0 + passive_value(); battle.note_passive(actor_id, passive_skill_id)
					for _hit in range(int(skill_data.get("hits", 1))): victim.take_damage(damage, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"multi_hit":int(skill_data.get("hits", 1)) > 1})
					victim.apply_armor_break(minf(0.8, float(skill_data.get("armor_break", 0.18)) * armor_break_multiplier()), float(skill_data.get("duration", 5.0)))
					if skill_data.has("knockback"):
						var pushed: Vector2 = victim.position + position.direction_to(victim.position) * float(skill_data.knockback)
						pushed.x = clampf(pushed.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0); pushed.y = clampf(pushed.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
						if not battle.point_blocked(pushed): victim.position = pushed
				skill_timer = cooldown; battle.on_skill(self); combat_event.emit("%s 施放【%s】，破甲斩击%d个目标" % [_name(), _skill_name(), victims.size()]); return true
		"piercing_shot":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 285.0)))):
				var ignore := float(skill_data.get("armor_ignore", 0.4)) + (passive_value() if passive_data.get("effect", "") == "armor_ignore" else 0.0)
				if passive_data.get("effect", "") == "armor_ignore": battle.note_passive(actor_id, passive_skill_id)
				target.take_damage(attack * power + target.defense * 0.55 * ignore, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"bypass_evasion":true})
				battle.spawn_tracer(position, target.position, _skill_color()); skill_timer = cooldown; battle.on_skill(self); return true
		"charm_control":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 230.0)))):
				target.take_damage(attack * 0.55, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
				target.apply_armor_break(minf(0.8, float(skill_data.get("armor_break", 0.16)) * armor_break_multiplier()), 5.0)
				target.apply_hard_control(float(skill_data.get("duration", 2.2)))
				var haste := passive_value() if passive_data.get("effect", "") == "control_haste" else power
				for member in allied_units(4): member.reduce_current_cooldowns(haste)
				if passive_data.get("effect", "") == "control_haste": battle.note_passive(actor_id, passive_skill_id)
				skill_timer = cooldown; battle.on_skill(self); combat_event.emit("%s 施放【%s】，魅惑并暴露破绽" % [_name(), _skill_name()]); return true
		"burn_area":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 210.0)))):
				var victims: Array = battle.enemies_near(target.position, faction, 125.0, 8)
				var mastery := 1.0
				if passive_data.get("effect", "") == "burn_master": battle.note_passive(actor_id, passive_skill_id)
				for victim in victims:
					victim.take_damage(attack * power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
					if actor_id == "ren_yingying":
						victim.apply_slow(0.28, float(skill_data.get("duration", 5.0)))
						victim.apply_hard_control(0.45)
					elif actor_id == "jaina_proudmoore":
						victim.apply_frost_dot(attack * float(skill_data.get("dot_power", 0.18)), float(skill_data.get("duration", 5.0)), self, combat_source_snapshot(self, "elemental", str(actor_data.get("skill", ""))))
					else:
						var burn_duration := float(skill_data.get("duration", 6.0))
						if str(actor_data.get("skill", "")) == "fire_spin" and victim.burn_time > 0.0:
							burn_duration = minf(10.0, victim.burn_time + 2.5)
						victim.apply_burn(attack * float(skill_data.get("dot_power", 0.24)) * mastery, burn_duration, self, combat_source_snapshot(self, "elemental", str(actor_data.get("skill", ""))))
				skill_timer = cooldown; battle.on_skill(self); combat_event.emit("%s 施放【%s】，点燃%d个目标" % [_name(), _skill_name(), victims.size()]); return true
		"leech_vine":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 195.0)))):
				target.take_damage(attack * power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
				target.apply_poison(attack * power * 0.34, float(skill_data.get("duration", 6.0)), self, combat_source_snapshot(self, "elemental", str(actor_data.get("skill", ""))))
				var wounded = battle.lowest_health_ally(self, 9999.0)
				if wounded != null: wounded.apply_hot(active_heal_amount(attack * power * 1.4), float(skill_data.get("duration", 6.0)), self, combat_source_snapshot(self, "none", str(actor_data.get("skill", "")) + ":hot"))
				skill_timer = cooldown; battle.on_skill(self); return true
		"shell_guard":
			var shield_power := power * shield_power_multiplier()
			add_shield(max_hp * shield_power, float(skill_data.get("duration", 4.5)), self, str(actor_data.get("skill", "")))
			for victim in battle.enemies_near(position, faction, float(skill_data.get("range", 220.0)), 12): victim.target = self; victim.taunt_timer = float(skill_data.get("duration", 4.5))
			var protected = battle.lowest_health_ally(self, 9999.0)
			if protected != null and protected != self: protected.add_shield(protected.max_hp * shield_power * 0.55, float(skill_data.get("duration", 4.5)), self, str(actor_data.get("skill", "")))
			skill_timer = cooldown; battle.on_skill(self); return true
		"armor_break_shot":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 220.0)))):
				var ignore := passive_value() if passive_data.get("effect", "") == "armor_ignore" else 0.0
				if passive_data.get("effect", "") == "armor_ignore": battle.note_passive(actor_id, passive_skill_id)
				target.take_damage(attack * power + target.defense * 0.55 * ignore, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"bypass_evasion":str(actor_data.get("skill", "")) == "aura_sphere"})
				target.apply_armor_break(minf(0.8, float(skill_data.get("armor_break", 0.25)) * armor_break_multiplier()), float(skill_data.get("duration", 5.0)))
				skill_timer = cooldown; battle.on_skill(self); return true
		"ally_guard":
			var ally = battle.lowest_health_ally(self, 9999.0)
			if ally != null:
				var bonus := shield_power_multiplier()
				if passive_data.get("effect", "") == "shield_healing": battle.note_passive(actor_id, passive_skill_id)
				ally.add_shield(ally.max_hp * power * bonus, float(skill_data.get("duration", 6.0)), self, str(actor_data.get("skill", "")))
				ally.heal(active_heal_amount(attack * 0.45 * bonus), self, true, {"source_snapshot":combat_source_snapshot(self, "none", str(actor_data.get("skill", "")))})
				if ally != self: add_shield(max_hp * power * 0.45 * bonus, float(skill_data.get("duration", 6.0)), self, str(actor_data.get("skill", "")))
				skill_timer = cooldown; battle.on_skill(self); return true
		"dive_guard":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 150.0)))):
				position = position.move_toward(target.position, minf(80.0, position.distance_to(target.position) - 28.0))
				for victim in battle.enemies_near(position, faction, 105.0, 6): victim.take_damage(attack * power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
				apply_damage_reduction(0.22, float(skill_data.get("duration", 4.0)))
				skill_timer = cooldown; battle.on_skill(self); return true
		"multi_hit_slow":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 190.0)))):
				var multi_bonus := 1.0 + passive_effect_total("multi_hit_bonus")
				for _hit in range(int(skill_data.get("hits", 4))): target.take_damage(attack * power * multi_bonus, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"multi_hit":true})
				target.apply_slow(float(skill_data.get("slow", 0.25)), float(skill_data.get("duration", 4.0)))
				if skill_data.has("attack_weaken"): target.apply_attack_weaken(float(skill_data.attack_weaken), float(skill_data.get("duration", 4.0)))
				skill_timer = cooldown; battle.on_skill(self); return true
		"multi_hit":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", float(actor_data.get("attack_range", 60.0)))))):
				var hit_count := int(skill_data.get("hits", 3))
				var multi_bonus := 1.0 + passive_effect_total("multi_hit_bonus")
				if str(actor_data.get("skill", "")) == "iron_hook":
					var victims: Array = battle.enemies_near(target.position, faction, 105.0, 5)
					for hit in range(hit_count):
						var victim = victims[hit % victims.size()]
						victim.take_damage(attack * power * multi_bonus * (1.35 if hit == hit_count - 1 else 1.0), self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"multi_hit":true})
				elif float(skill_data.get("splash_radius", 0.0)) > 0.0:
					var splash_targets: Array = battle.enemies_near(target.position, faction, float(skill_data.splash_radius), 6)
					for _hit in range(hit_count):
						for victim in splash_targets: victim.take_damage(attack * power * multi_bonus, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"multi_hit":true})
				else:
					for hit in range(hit_count):
						var hit_power := power * multi_bonus * (1.35 if hit == hit_count - 1 else 1.0)
						if str(actor_data.get("skill", "")) == "endless_annihilation" and hit == hit_count - 1 and target.hp / maxf(1.0, target.max_hp) <= 0.35:
							hit_power *= 1.65
						target.take_damage(attack * hit_power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true,"multi_hit":true})
				skill_timer = cooldown; battle.on_skill(self); return true
		"emergency_heal":
			var wounded = battle.lowest_health_ally(self, 9999.0)
			var target_key := str(wounded.actor_id) if is_instance_valid(wounded) else ""
			var now := float(battle.elapsed)
			if wounded != null and wounded.hp / maxf(1.0, wounded.max_hp) <= float(skill_data.get("threshold", 0.42)) and not rescue_used_targets.has(target_key) and now >= rescue_ready_at:
				wounded.heal(active_heal_amount(attack * power * (1.0 + (passive_value() if passive_data.get("effect", "") == "healing" else 0.0))), self, true, {"source_snapshot":combat_source_snapshot(self, "none", str(actor_data.get("skill", "")))})
				wounded.apply_damage_reduction(0.28, 4.0)
				rescue_used_targets[target_key] = true
				rescue_ready_at = now + float(skill_data.get("rescue_cooldown", 45.0))
				skill_timer = cooldown; battle.on_skill(self); return true
		"blood_bargain":
			if hp > max_hp * 0.3:
				hp = maxf(1.0, hp - max_hp * float(skill_data.get("health_cost", 0.12)))
				for member in allied_units(4): member.reduce_current_cooldowns(power); member.haste_power = power; member.haste_time = float(skill_data.get("duration", 6.0))
				skill_timer = cooldown; battle.on_skill(self); return true
		"capped_execute_area":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 245.0)))):
				for victim in battle.enemies_near(target.position, faction, 145.0, 8):
					var damage := attack * power
					if victim.hp / maxf(1.0, victim.max_hp) <= 0.35: damage *= 1.0 + float(skill_data.get("execute_bonus", 0.45))
					if victim.actor_data.has("boss_id"): damage = minf(damage, victim.max_hp * float(skill_data.get("boss_cap", 0.12)))
					victim.take_damage(damage, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
				skill_timer = cooldown; battle.on_skill(self); return true
		"gravity_taunt":
			var victims: Array = battle.enemies_near(position, faction, float(skill_data.get("range", 210.0)), 12)
			if not victims.is_empty():
				for victim in victims:
					victim.apply_slow(float(skill_data.get("slow", 0.55)), float(skill_data.get("duration", 3.0))); victim.apply_hard_control(0.8); victim.target = self
					if actor_id == "qiao_feng": victim.take_damage(attack * power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true})
				add_shield(max_hp * power * shield_power_multiplier()); skill_timer = cooldown; battle.on_skill(self); return true
		"nightmare":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 245.0)))):
				var status_bonus := 1.0 + (passive_value() if passive_data.get("effect", "") == "status_amplifier" else 0.0)
				target.take_damage(attack * power, self, false, {"kind":"skill","skill_id":actor_data.skill,"allow_triggers":true}); target.apply_hard_control(float(skill_data.get("duration", 5.0)) * 0.35 * status_bonus); target.apply_slow(minf(0.65, 0.3 * status_bonus), minf(8.0, float(skill_data.get("duration", 5.0)) * status_bonus))
				if skill_data.has("attack_weaken"): target.apply_attack_weaken(float(skill_data.attack_weaken), float(skill_data.get("duration", 5.0)))
				skill_timer = cooldown; battle.on_skill(self); return true
		"mirror_safe":
			if valid_enemy_in_range(target, effective_cast_range(float(skill_data.get("range", 250.0)))):
				var mirror_power := power
				var mirror_type := "physical"
				var whitelist := ["damage", "area_damage", "piercing_shot", "armor_break_shot", "multi_hit", "multi_hit_slow", "execute_cone", "capped_execute_area"]
				for member in allied_units(8):
					if member == self or str(member.skill_data.get("type", "")) not in whitelist: continue
					mirror_power *= clampf(float(member.skill_data.get("power", 1.0)), 0.8, 1.8)
					mirror_type = str(member.skill_data.get("damage_type", "physical"))
					break
				# Resolve a copied direct effect with Zero's own stats. Never invoke the
				# original skill function, so mirror/ summon/ rescue recursion is impossible.
				target.take_damage(attack * mirror_power, self, false, {"kind":"skill","skill_id":actor_data.skill,"damage_type":mirror_type,"allow_triggers":true,"mirrored":true})
				skill_timer = cooldown; battle.on_skill(self); return true
		"team_hot":
			var applied := false
			var cleansed := false
			for member in allied_units(int(skill_data.get("targets", 4))):
				if member.hp < member.max_hp: member.apply_hot(active_heal_amount(attack * power * (1.0 + (passive_value() if passive_data.get("effect", "") == "healing" else 0.0))), float(skill_data.get("duration", 7.0)), self, combat_source_snapshot(self, "none", str(actor_data.get("skill", "")) + ":hot")); applied = true
				if passive_skill_id == "pure_heart_benevolence" and not cleansed and member.has_negative_status(): member.cleanse_statuses(); cleansed = true; applied = true
			if applied: skill_timer = cooldown; battle.on_skill(self); return true
		"hero_summon":
			var summon_count := 0
			for member in battle.heroes:
				if is_instance_valid(member) and member.is_summon and member.summon_owner_id == actor_id: summon_count += 1
			if summon_count < int(skill_data.get("summon_cap", 2)):
				var minion = battle.spawn_unit("medicine_avatar", "heroes", position + Vector2(35 + summon_count * 24, 25), {"summoned":true})
				minion.is_summon = true; minion.summon_owner_id = actor_id; minion.summon_lifetime = float(skill_data.get("duration", 9.0)); minion.max_hp = max_hp * 0.3; minion.hp = minion.max_hp; minion.attack = attack * power * (1.0 + (passive_value() if passive_data.get("effect", "") == "summon_damage" else 0.0)); minion.defense = defense * 0.5
				skill_timer = cooldown; battle.on_skill(self); return true
	return false

func take_damage(raw_amount: float, source, critical: bool = false, context: Dictionary = {}) -> Dictionary:
	var live_source = valid_combat_source(source)
	var safe_context: Dictionary = context.duplicate(true)
	var source_snapshot: Dictionary = safe_context.get("source_snapshot", {})
	if source_snapshot.is_empty() and live_source != null:
		source_snapshot = combat_source_snapshot(live_source)
	safe_context["source_snapshot"] = source_snapshot
	safe_context["source_actor_id"] = str(source_snapshot.get("actor_id", ""))
	if str(safe_context.get("skill_id", "")).is_empty() and not str(source_snapshot.get("skill_id", "")).is_empty():
		safe_context["skill_id"] = str(source_snapshot.skill_id)
	var damage_type := resolve_damage_type(live_source, safe_context)
	var result := {"raw":raw_amount, "damage_type":damage_type, "defense":defense, "reduction":0.0, "shield_absorbed":0.0, "hp_damage":0.0, "hp_before":hp, "reason":""}
	if dead:
		result.reason = "target_dead"
		battle.record_damage_resolution(live_source, self, result, safe_context)
		return result
	if not is_finite(raw_amount) or raw_amount <= 0.0:
		result.reason = "invalid_raw_damage"
		battle.record_damage_resolution(live_source, self, result, safe_context)
		return result
	var evasion := passive_effect_total("evasion") + (passive_value() if passive_data.get("effect", "") == "evasion" else 0.0) + (temporary_evasion if temporary_evasion_time > 0.0 else 0.0)
	if passive_data.get("effect", "") == "team_guard_evasion": evasion += float(passive_data.get("evasion", 0.12))
	if live_source != null:
		evasion = maxf(0.0, evasion - live_source.passive_effect_total("armor_ignore") * 0.5)
		if live_source.passive_skill_id == "fy_hero_sword_intent": evasion = maxf(0.0, evasion - float(live_source.passive_data.get("accuracy", 0.16)))
	if live_source != null and live_source.has_general_passive("dz_golden_eye"):
		evasion = maxf(0.0, evasion - live_source.general_passive_by_id("dz_golden_eye"))
	if not bool(safe_context.get("bypass_evasion", false)) and randf() < minf(0.75, evasion):
		show_number("闪避", Color("#D4F4FF"))
		result.reason = "evaded"
		battle.record_damage_resolution(live_source, self, result, safe_context)
		return result
	if damage_share_time > 0.0 and is_instance_valid(damage_share_source) and damage_share_source != self and not damage_share_source.dead:
		var shared := raw_amount * damage_share_ratio
		raw_amount -= shared
		damage_share_source.take_damage(shared, live_source, false, {"kind":"effect", "damage_type":damage_type, "allow_triggers":false, "shared":true, "source_snapshot":source_snapshot})
	elif damage_share_time > 0.0 and not is_instance_valid(damage_share_source):
		damage_share_time = 0.0
		damage_share_ratio = 0.0
		damage_share_source = null
	var typed_amount := raw_amount
	if damage_type == "physical": typed_amount *= 1.0 + float(source_snapshot.get("physical_damage", 0.0))
	elif damage_type == "elemental": typed_amount *= 1.0 + float(source_snapshot.get("elemental_damage", 0.0))
	if live_source != null and has_negative_status():
		var status_bonus: float = live_source.passive_effect_total("status_amplifier")
		if live_source.passive_data.get("effect", "") == "status_amplifier": status_bonus += live_source.passive_value()
		typed_amount *= 1.0 + minf(0.60, status_bonus)
	if live_source != null and live_source.passive_skill_id == "hunting_instinct" and armor_break_time > 0.0:
		typed_amount *= 1.0 + live_source.passive_value()
	if live_source != null and live_source.passive_skill_id == "qin_resonance" and burn_time > 0.0 and damage_type == "elemental":
		typed_amount *= 1.0 + live_source.passive_value()
	if live_source != null and live_source.passive_data.get("effect", "") == "burn_master" and burn_time > 0.0:
		typed_amount *= 1.0 + live_source.passive_value()
	if live_source != null and live_source.passive_skill_id == "wow_killing_machine" and (frost_time > 0.0 or slow_time > 0.0):
		typed_amount *= 1.0 + live_source.passive_value()
	if live_source != null and live_source.temporary_attack_bonus_time > 0.0:
		typed_amount *= 1.0 + live_source.temporary_attack_bonus
	if live_source != null:
		typed_amount += defense * 0.55 * minf(0.75, live_source.passive_effect_total("armor_ignore"))
		if live_source.passive_skill_id == "naruto_sage_affinity" and live_source.metamorphosis_time > 0.0:
			typed_amount *= 1.0 + live_source.passive_value()
			battle.note_passive(live_source.actor_id, live_source.passive_skill_id)
	var amount := float(preview_damage(typed_amount))
	# Final damage is an independent post-defense offensive multiplier.
	amount *= 1.0 + float(source_snapshot.get("final_damage", 0.0))
	var reduction_factor := 1.0
	# Equipment reduction remains a permanent independent multiplier and never
	# enters the temporary reduction state used by skills.
	reduction_factor *= 1.0 - clampf(damage_reduction, 0.0, 0.85)
	if actor_data.get("boss_mechanic", "") == "stone_skin": reduction_factor *= 0.78
	if "iron_wall" in rift_affixes: reduction_factor *= 0.82
	var exclusive_reduction_active: bool = passive_data.get("effect", "") == "damage_reduction"
	if passive_skill_id == "imperial_pressure":
		exclusive_reduction_active = not battle.enemies_near(position, faction, 135.0, 1).is_empty()
	if exclusive_reduction_active:
		reduction_factor *= 1.0 - clampf(passive_value(), 0.0, 0.85)
		battle.note_passive(actor_id, passive_skill_id)
		if shield > 0.0: reduction_factor *= 0.88
	if passive_data.get("effect", "") == "high_hp_guard" and hp / maxf(1.0, max_hp) >= 0.70:
		reduction_factor *= 1.0 - clampf(passive_value(), 0.0, 0.45)
		battle.note_passive(actor_id, passive_skill_id)
	reduction_factor *= 1.0 - clampf(passive_effect_total("damage_reduction"), 0.0, 0.85)
	reduction_factor *= 1.0 - clampf(friend_guard_aura(), 0.0, 0.40)
	if critical: reduction_factor *= 1.0 - clampf(passive_effect_total("critical_reduction"), 0.0, 0.60)
	if temporary_reduction_time > 0.0: reduction_factor *= 1.0 - clampf(temporary_reduction, 0.0, 0.85)
	if vulnerability_time > 0.0: reduction_factor *= 1.0 + clampf(vulnerability_power, 0.0, 0.40)
	result.reduction = 1.0 - reduction_factor
	amount = maxf(1.0, roundf(amount * reduction_factor))
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		result.shield_absorbed = absorbed
		consume_shield_layers(absorbed)
		show_number("护盾吸收 %d" % roundi(absorbed), Color("#80C8FF"))
	if amount <= 0:
		result.reason = "shield_absorbed"
		battle.record_damage_resolution(live_source, self, result, safe_context)
		if not battle.suppress_combat_visuals: queue_redraw()
		return result
	amount = maxf(1.0, roundf(amount))
	last_damage_source = live_source
	last_damage_source_id = str(source_snapshot.get("actor_id", ""))
	hp = maxf(0.0, hp - amount)
	result.hp_damage = amount
	result.reason = "applied"
	hit_flash = 0.12
	show_number(("暴击 -%d" if critical else "-%d") % amount, Color("#FFE26A") if critical else Color("#FF8278"))
	health_changed.emit(self)
	battle.on_damage(live_source, self, amount, safe_context)
	battle.record_damage_resolution(live_source, self, result, safe_context)
	var recovery := passive_effect_total("damage_recovery")
	if hp > 0.0 and recovery > 0.0:
		heal(minf(max_hp * 0.04, amount * recovery), self, false)
	if live_source != null and live_source != self:
		if actor_data.get("boss_mechanic", "") == "counter_guard":
			live_source.take_damage(amount * 0.18, self, false, {"kind":"effect", "allow_triggers":false})
		if "counter" in rift_affixes:
			live_source.take_damage(amount * 0.12, self, false, {"kind":"effect", "allow_triggers":false})
		if temporary_counter_time > 0.0:
			live_source.take_damage(attack * temporary_counter, self, false, {"kind":"effect", "damage_type":"physical", "skill_id":"tk_counter_stance", "allow_triggers":false})
		var counter_chance := passive_effect_total("counter")
		if counter_chance > 0.0 and randf() < counter_chance:
			live_source.take_damage(attack * 0.65, self, false, {"kind":"effect", "allow_triggers":false})
	if not battle.suppress_combat_visuals: queue_redraw()
	if hp <= 0.0:
		dead = true
		velocity = Vector2.ZERO
		combat_event.emit("%s 被 %s 击败" % [_name(), str(source_snapshot.get("name", "环境效果"))])
		died.emit(self)
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.35)
		tween.tween_callback(queue_free)
	return result

func resolve_damage_type(source, context: Dictionary) -> String:
	var explicit := str(context.get("damage_type", ""))
	if explicit in ["physical", "elemental", "none"]: return explicit
	if not is_instance_valid(source):
		return str(context.get("source_snapshot", {}).get("damage_type", "none"))
	if not (source is BattleUnit): return "none"
	match str(context.get("kind", "")):
		"basic": return str(source.actor_data.get("basic_damage_type", "physical"))
		"skill":
			var skill_id := str(context.get("skill_id", ""))
			if source.battle != null and source.battle.general_skills_config.has(skill_id):
				return str(source.battle.general_skills_config[skill_id].get("damage_type", "none"))
			if skill_id == str(source.actor_data.get("skill", "")):
				return str(source.skill_data.get("damage_type", "none"))
	return "none"

func basic_heal_amount(base_amount: float) -> float:
	return base_amount * (1.0 + healing_effect)

func active_heal_amount(base_amount: float) -> float:
	var active_multiplier := ACTIVE_HEAL_MULTIPLIER if faction == "heroes" else 1.0
	return base_amount * active_multiplier * (1.0 + healing_effect)

func preview_damage(raw_amount: float) -> int:
	var effective_defense := defense * (1.0 - armor_break_power if armor_break_time > 0.0 else 1.0)
	return maxi(1, roundi(maxf(1.0, raw_amount - effective_defense * 0.55)))

func heal(raw_amount: float, _source, show_text: bool = true, context: Dictionary = {}) -> void:
	if faction == "heroes" and battle != null and not battle.active_rift_context.is_empty():
		var boss_affixes: Array = []
		for enemy in battle.enemies:
			if is_instance_valid(enemy) and not enemy.dead: boss_affixes.append_array(enemy.rift_affixes)
		if "healing_suppression" in boss_affixes: raw_amount *= 0.70
	var amount := mini(roundi(raw_amount), roundi(max_hp - hp))
	if amount <= 0:
		return
	hp += amount
	var live_source = valid_combat_source(_source)
	var source_snapshot: Dictionary = context.get("source_snapshot", {})
	if source_snapshot.is_empty() and live_source != null:
		source_snapshot = combat_source_snapshot(live_source)
	battle.on_heal(live_source, amount, source_snapshot)
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
	rally_target = Vector2(
		clampf(point.x, 18.0, BattleMapScript.ARENA_SIZE.x - 18.0),
		clampf(point.y, 28.0, BattleMapScript.ARENA_SIZE.y - 18.0)
	)
	has_rally = true
	rally_timeout = 3.0
	nav_path.clear()

func add_shield(amount: float, duration: float = 6.0, provider = null, source_key: String = "") -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	var previous := shield
	shield = maxf(shield, amount)
	var added := shield - previous
	var live_provider = valid_combat_source(provider) if provider != null else self
	if live_provider == null: live_provider = self
	if added > 0.0:
		var provider_id := str(live_provider.summon_owner_id) if bool(live_provider.is_summon) and not str(live_provider.summon_owner_id).is_empty() else str(live_provider.actor_id)
		var key := source_key if not source_key.is_empty() else str(live_provider.actor_data.get("skill", "shield"))
		shield_layers.append({"remaining":added,"provider_id":provider_id,"source_key":key})
	shield_time = maxf(shield_time, duration)
	show_number("◆ 护盾", Color("#80C8FF"))
	queue_redraw()

func consume_shield_layers(amount: float) -> void:
	var remaining := amount
	while remaining > 0.0 and not shield_layers.is_empty():
		var layer: Dictionary = shield_layers[0]
		var consumed := minf(remaining, float(layer.get("remaining", 0.0)))
		layer.remaining = float(layer.get("remaining", 0.0)) - consumed
		remaining -= consumed
		if faction == "heroes" and consumed > 0.0:
			battle.on_friendly_shield_absorbed(str(layer.get("provider_id", "")), str(layer.get("source_key", "shield")), consumed)
		if float(layer.remaining) <= 0.001: shield_layers.pop_front()
		else: shield_layers[0] = layer

func apply_poison(damage_per_second: float, duration: float, source, source_snapshot: Dictionary = {}) -> void:
	poison_damage = maxf(poison_damage, damage_per_second)
	poison_time = maxf(poison_time, duration)
	poison_source = valid_combat_source(source)
	var inferred_skill := str(source.actor_data.get("skill", "")) if is_instance_valid(source) else ""
	poison_source_snapshot = source_snapshot.duplicate(true) if not source_snapshot.is_empty() else combat_source_snapshot(source, "elemental", inferred_skill)
	show_number("☠ 中毒", Color("#C58DFF"))
	queue_redraw()

func apply_burn(damage_per_second: float, duration: float, source, source_snapshot: Dictionary = {}) -> void:
	burn_damage = maxf(burn_damage, damage_per_second)
	burn_time = maxf(burn_time, duration)
	burn_source = valid_combat_source(source)
	var inferred_skill := str(source.actor_data.get("skill", "")) if is_instance_valid(source) else ""
	burn_source_snapshot = source_snapshot.duplicate(true) if not source_snapshot.is_empty() else combat_source_snapshot(source, "elemental", inferred_skill)
	show_number("♨ 燃烧", Color("#FF9B62"))

func apply_hot(total_power: float, duration: float, source, source_snapshot: Dictionary = {}) -> void:
	hot_amount = maxf(hot_amount, total_power / maxf(1.0, duration))
	hot_time = maxf(hot_time, duration)
	hot_source = valid_combat_source(source)
	hot_source_snapshot = source_snapshot.duplicate(true) if not source_snapshot.is_empty() else combat_source_snapshot(source)
	show_number("✚ 持续恢复", Color("#78F0A8"))

func apply_shock(duration: float) -> void:
	shock_time = maxf(shock_time, duration)
	attack_timer += duration * 0.45
	skill_timer += duration * 0.25
	show_number("⚡ 麻痹", Color("#FFE36A"))

func apply_frost_dot(damage_per_second: float, duration: float, source, source_snapshot: Dictionary = {}) -> void:
	frost_damage = maxf(frost_damage, damage_per_second)
	frost_time = maxf(frost_time, minf(duration, 8.0))
	frost_source = valid_combat_source(source)
	var inferred_skill := str(source.actor_data.get("skill", "")) if is_instance_valid(source) else ""
	frost_source_snapshot = source_snapshot.duplicate(true) if not source_snapshot.is_empty() else combat_source_snapshot(source, "elemental", inferred_skill)
	apply_slow(0.28, duration)

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

func apply_attack_weaken(power: float, duration: float) -> void:
	attack_weaken_power = maxf(attack_weaken_power, clampf(power, 0.0, 0.45))
	attack_weaken_time = maxf(attack_weaken_time, duration)
	show_number("攻击降低", Color("#B9A5E8"))

func apply_damage_share(source, ratio: float, duration: float) -> void:
	damage_share_source = valid_combat_source(source)
	damage_share_ratio = clampf(ratio, 0.0, 0.6)
	damage_share_time = duration

func cleanse_statuses() -> void:
	poison_time = 0.0; burn_time = 0.0; frost_time = 0.0; slow_time = 0.0; armor_break_time = 0.0; shock_time = 0.0
	poison_source = null; burn_source = null; frost_source = null
	poison_source_snapshot.clear(); burn_source_snapshot.clear(); frost_source_snapshot.clear()
	show_number("净化", Color("#F8F2C0"))

func has_negative_status() -> bool:
	return poison_time > 0.0 or burn_time > 0.0 or frost_time > 0.0 or slow_time > 0.0 or armor_break_time > 0.0 or shock_time > 0.0

func friend_guard_aura() -> float:
	var total := passive_effect_total("friend_guard")
	var allies: Array = battle.heroes if faction == "heroes" else battle.enemies
	for member in allies:
		if is_instance_valid(member) and member != self and not member.dead and position.distance_to(member.position) <= 220.0:
			total += member.passive_effect_total("friend_guard")
			if member.passive_data.get("effect", "") == "team_guard_evasion": total += member.passive_value()
	return total

func on_skill_casted() -> void:
	if passive_data.get("effect", "") == "cast_momentum" or passive_skill_id == "hy_supreme_grandmaster":
		unstable_casts = mini(3, unstable_casts + 1)
		unstable_window = 7.0
		var cast_power := passive_value() if passive_data.get("effect", "") == "cast_momentum" else float(passive_data.get("cast_bonus", 0.06))
		temporary_attack_bonus = maxf(temporary_attack_bonus, cast_power * unstable_casts)
		temporary_attack_bonus_time = maxf(temporary_attack_bonus_time, 6.0)
		battle.note_passive(actor_id, passive_skill_id)
		return
	if passive_skill_id != "unstable_bloodline": return
	unstable_casts += 1
	unstable_window = 8.0
	if unstable_casts >= 3:
		vulnerability_power = 0.16
		vulnerability_time = 4.0
		unstable_casts = 0
		show_number("血统失控 +16%承伤", Color("#FF8FA8"))

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
		"charge_burn":
			for victim in battle.enemies_near(position, faction, 230.0, 4): victim.apply_burn(attack * 0.13, 5.0, self)
		"summon", "poison_summon": summon_boss_minion(str(actor_data.get("boss_mechanic", "")) == "poison_summon")
		"alchemy_burst": add_shield(max_hp * 0.12, 4.0); apply_damage_reduction(0.12, 4.0)
		"iron_wall": add_shield(max_hp * 0.16, 5.0); apply_damage_reduction(0.18, 5.0)
		"armor_break_aura":
			for victim in battle.enemies_near(position, faction, 255.0, 8): victim.apply_armor_break(0.24, 6.0)
		"gravity_field":
			for victim in battle.enemies_near(position, faction, 260.0, 8): victim.apply_slow(0.45, 4.0); victim.apply_hard_control(0.6)
		"phase_control":
			for victim in battle.enemies_near(position, faction, 250.0, 6): victim.apply_shock(3.0)
		"charge_slash", "combo_charge": haste_power = 0.2; haste_time = 5.0
		"moving_area": temporary_evasion = 0.18; temporary_evasion_time = 4.0
		"frost_field":
			for victim in battle.enemies_near(position, faction, 260.0, 8): victim.apply_slow(0.42, 4.0)
		"periodic_burst":
			for victim in battle.enemies_near(position, faction, 280.0, 8): victim.apply_shock(2.5)
		"illusion_decoy": add_shield(max_hp * 0.1, 4.0); temporary_evasion = 0.2; temporary_evasion_time = 4.0
		"dual_phase": temporary_counter = 0.3; temporary_counter_time = 5.0; add_shield(max_hp * 0.06, 4.0)
		"evasion_counter": temporary_evasion = 0.24; temporary_evasion_time = 5.0; temporary_counter = 0.28; temporary_counter_time = 5.0; haste_power = 0.18; haste_time = 5.0
		"critical_fury": temporary_attack_bonus = 0.22; temporary_attack_bonus_time = 5.0; haste_power = 0.22; haste_time = 5.0
		"final_burst_phases":
			haste_power = 0.18 if hp / maxf(1.0, max_hp) > 0.25 else 0.32
			haste_time = 5.0
			if hp / maxf(1.0, max_hp) <= 0.55: add_shield(max_hp * 0.05, 3.0)
	if "elemental" in rift_affixes:
		for victim in battle.enemies_near(position, faction, 260.0, 8): victim.take_damage(attack * 0.18, self, false, {"kind":"effect","allow_triggers":false})
	if "summon" in rift_affixes:
		var alive_allies := 0
		for ally in battle.enemies:
			if is_instance_valid(ally) and not ally.dead: alive_allies += 1
		if alive_allies < 3:
			var summon_id := boss_minion_actor_id()
			var minion = battle.spawn_unit(summon_id, "enemies", position + Vector2(randf_range(-65, 65), randf_range(-55, 55)))
			minion.monster_level = monster_level; minion.max_hp *= 1.0 + monster_level * 0.08; minion.hp = minion.max_hp

func summon_boss_minion(poisonous: bool) -> void:
	var alive_allies := 0
	for ally in battle.enemies:
		if is_instance_valid(ally) and not ally.dead: alive_allies += 1
	if alive_allies >= 3: return
	var summon_id := boss_minion_actor_id()
	var minion = battle.spawn_unit(summon_id, "enemies", position + Vector2(randf_range(-60, 60), randf_range(-50, 50)))
	minion.monster_level = monster_level; minion.max_hp *= 1.0 + monster_level * 0.06; minion.hp = minion.max_hp
	if poisonous: minion.actor_data.boss_mechanic = "venom_strike"

func boss_minion_actor_id() -> String:
	match str(actor_data.get("world", "")):
		"三国": return "yellow_turban"
		"龙族": return "dragon_deadpool"
		"逆水寒": return "jianghu_raider"
		"魔兽世界": return "wow_ghoul"
		"金庸": return "jy_assassin"
		"秦时明月": return "qin_mechanism_beast"
		"火影忍者": return "naruto_rogue_ninja"
		"黄易": return "hy_demon_disciple"
		"风云": return "fy_tianxia_guard"
	return "zubat"

func apply_hard_control(duration: float) -> float:
	# Boss hard-control duration diminishes per application and is capped cumulatively.
	var cap := 4.0 if actor_data.has("boss_id") else 8.0
	var aura_resistance := minf(0.35, battle.party_passive_value("team_elemental_control")) if faction == "heroes" and is_instance_valid(battle) and battle.has_method("party_passive_value") else 0.0
	if passive_skill_id == "hy_zen_demon_union": aura_resistance += float(passive_data.get("control_resistance", 0.16))
	var applied := minf(duration * (1.0 - clampf(control_resistance + aura_resistance, 0.0, 0.90)), maxf(0.0, cap - accumulated_control))
	accumulated_control += applied
	if actor_data.has("boss_id"):
		control_resistance = minf(0.85, control_resistance + 0.15)
	attack_timer += applied
	skill_timer += applied
	return applied

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
	final_damage = clampf(float(stats.get("final_damage", 0)), 0.0, float(rules.get("max_final_damage", 0.5)))
	damage_reduction = clampf(float(stats.get("damage_reduction", 0)), 0.0, float(rules.get("max_damage_reduction", 0.45)))
	healing_effect = clampf(float(stats.get("healing_effect", 0)), 0.0, float(rules.get("max_healing_effect", 1.0)))
	life_regen = 0.0
	emergency_regen = 0.0
	control_resistance = 0.35 if actor_data.has("boss_id") else 0.0
	attack_range = resolved_attack_range()
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
			"low_hp_regeneration": emergency_regen += max_hp * value
			"move_speed": move_speed = float(actor_data.get("move_speed", 80)) * (1.0 + value)
			"elemental_damage": elemental_damage += value
			"healing_regeneration": healing_effect += value; life_regen += max_hp * float(general_data.get("regen", 0.003))
			"critical_control": crit_chance += value; control_resistance += float(general_data.get("control_resistance", 0.10))
			"physical_health": physical_damage += value; max_hp *= 1.0 + float(general_data.get("health", 0.08))
			"elemental_cooldown": elemental_damage += value; cooldown_reduction += float(general_data.get("cooldown", 0.06))
			"hybrid_damage": physical_damage += value; elemental_damage += value
			"control_resistance": control_resistance += value
			"defense_guard": defense *= 1.0 + float(general_data.get("defense", 0.10))
			"health_counter": max_hp *= 1.0 + float(general_data.get("health", 0.12))
			"guard_survival": max_hp *= 1.0 + float(general_data.get("health", 0.08))
			"physical_defense": physical_damage += value; defense *= 1.0 + float(general_data.get("defense", 0.08))
			"regeneration_cooldown": life_regen += max_hp * value; cooldown_reduction += float(general_data.get("cooldown", 0.07))
			"critical_power": crit_chance += value; crit_damage += float(general_data.get("crit_damage", 0.18))
	match passive_data.get("effect", ""):
		"health_regen":
			max_hp *= 1.0 + passive_value()
			life_regen += float(passive_data.get("regen", 0.0)) * (1.0 + (passive_skill_level - 1) * 0.12)
		"attack_speed":
			attack_speed = clampf(attack_speed + passive_value(), 0.0, float(rules.get("max_attack_speed", 1.5)))
		"elemental_damage":
			elemental_damage += passive_value()
		"cast_momentum": elemental_damage += float(passive_data.get("elemental_bonus", 0.0))
		"critical":
			if passive_skill_id != "hunting_instinct": crit_chance += passive_value()
		"cooldown_reduction": cooldown_reduction += passive_value()
		"second_wind": emergency_regen += max_hp * passive_value()
		"armor_ignore": physical_damage += float(passive_data.get("physical_bonus", 0.0)) + passive_value()
		"sword_mastery":
			physical_damage += passive_value(); attack_range += float(passive_data.get("range_bonus", 0.0)); control_resistance += float(passive_data.get("control_resistance", 0.0))
		"critical_control_power": crit_damage += float(passive_data.get("crit_damage", 0.25)) + passive_value()
		"physical_guard": physical_damage += passive_value(); damage_reduction += float(passive_data.get("reduction", 0.10))
		"burn_master": max_hp *= 1.0 + float(passive_data.get("health", 0.0))
		"regen_cooldown": life_regen += max_hp * float(passive_data.get("regen", 0.007)) * (1.0 + (passive_skill_level - 1) * 0.08); cooldown_reduction += passive_value()
	if passive_skill_id == "hy_longevity_exclusive": life_regen += max_hp * float(passive_data.get("regen", 0.006))
	if passive_skill_id in ["hy_golden_core", "hy_love_sword_heart", "fy_hero_sword_intent"]: crit_damage += float(passive_data.get("crit_damage", 0.0))
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
		var actual_effect := str(row.data.get("effect", ""))
		var combined_match := (actual_effect == "guard_shield" and effect in ["damage_reduction", "shield_power"]) or (actual_effect == "damage_recovery" and effect == "damage_recovery") or (actual_effect == "defense_guard" and effect == "damage_reduction") or (actual_effect == "health_counter" and effect == "counter") or (actual_effect == "guard_survival" and effect == "damage_reduction") or (actual_effect == "evasion_burst_guard" and effect in ["evasion", "critical_reduction"])
		if actual_effect == effect or combined_match:
			if str(row.id) == "dz_unyielding_soul" and hp / maxf(1.0, max_hp) > 0.45: continue
			total += general_passive_value(str(row.id), row.data)
	return total

func passive_status_mastery(status: String) -> float:
	var total := 0.0
	for row in general_passive_datas:
		if str(row.data.get("effect", "")) == "status_mastery" and str(row.data.get("status", "")) == status:
			total += general_passive_value(str(row.id), row.data)
	return total

func has_general_passive(skill_id: String) -> bool:
	for row in general_passive_datas:
		if str(row.id) == skill_id: return true
	return false

func general_passive_by_id(skill_id: String) -> float:
	for row in general_passive_datas:
		if str(row.id) == skill_id: return general_passive_value(skill_id, row.data)
	return 0.0

func armor_break_multiplier() -> float:
	var value := general_passive_by_id("dz_alchemy_affinity") if has_general_passive("dz_alchemy_affinity") else 0.0
	if passive_skill_id == "fy_qilin_arm": value += float(passive_data.get("break_bonus", 0.20))
	return 1.0 + value

func shield_power_multiplier() -> float:
	var value := passive_effect_total("shield_power")
	if passive_data.get("effect", "") == "shield_healing": value += passive_value()
	return 1.0 + value

func trigger_general_on_hit(victim) -> void:
	if not is_instance_valid(victim) or victim.dead: return
	for row in general_passive_datas:
		var effect := str(row.data.get("effect", ""))
		if effect == "life_steal":
			heal(basic_heal_amount(attack * clampf(general_passive_value(str(row.id), row.data), 0.0, 0.10)), self, false)
			continue
		if effect == "on_hit_elemental":
			victim.take_damage(attack * general_passive_value(str(row.id), row.data), self, false, {"kind":"passive", "skill_id":str(row.id), "damage_type":"elemental", "allow_triggers":false})
			continue
		if effect != "on_hit_status": continue
		var chance := general_passive_value(str(row.id), row.data)
		if randf() > chance: continue
		match str(row.data.get("status", "")):
			"shock": victim.apply_shock(2.5)
			"poison": victim.apply_poison(attack * 0.12, 4.0, self)
			"burn": victim.apply_burn(attack * 0.12, 4.0, self)

func on_kill_trigger() -> void:
	var power := passive_effect_total("on_kill_haste")
	if power > 0.0:
		haste_power = maxf(haste_power, power)
		haste_time = maxf(haste_time, 5.0)
		temporary_attack_bonus = maxf(temporary_attack_bonus, power)
		temporary_attack_bonus_time = maxf(temporary_attack_bonus_time, 5.0)
		if has_general_passive("jy_zixia"): reduce_current_cooldowns(general_passive_by_id("jy_zixia"))

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
		"final_damage": final_damage,
		"damage_reduction": damage_reduction,
		"healing_effect": healing_effect,
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
	var true_boss := is_true_boss_unit()
	if hit_flash > 0:
		base = Color.WHITE
	if true_boss:
		draw_circle(Vector2.ZERO, 34, Color(accent, 0.16))
		draw_arc(Vector2.ZERO, 34, 0, TAU, 36, accent, 4)
	# Soft shadow, oversized head and compact body form the placeholder chibi silhouette.
	draw_chibi_ellipse(Vector2(0, 17), Vector2(21, 8), Color(0.05, 0.08, 0.08, 0.22))
	var artwork: Texture2D = ArtCatalogScript.texture("units", actor_id)
	var health_bar_y := -47.0
	var faction_marker_y := -36.0
	if artwork != null:
		var draw_rect := Rect2(-38, -58, 76, 83)
		var layout := ArtCatalogScript.layout("units", actor_id)
		if not layout.is_empty():
			var scale := clampf(float(layout.get("scale", 1.0)), 0.25, 3.0)
			var draw_size := Vector2(float(layout.get("width", 76.0)), float(layout.get("height", 83.0))) * scale
			var anchor_data: Array = layout.get("anchor", [0.5, 0.70])
			var anchor := Vector2(float(anchor_data[0]), float(anchor_data[1])) if anchor_data.size() >= 2 else Vector2(0.5, 0.70)
			var offset := Vector2(float(layout.get("offset_x", 0.0)), float(layout.get("offset_y", 0.0)))
			draw_rect = Rect2(offset - draw_size * anchor, draw_size)
		draw_texture_rect(artwork, draw_rect, false)
		health_bar_y = minf(health_bar_y, draw_rect.position.y - 8.0)
		faction_marker_y = health_bar_y - 7.0
	else:
		draw_circle(Vector2(0, 5), 16, base.darkened(0.16))
		draw_rect(Rect2(-12, -2, 24, 26), base, true)
		draw_circle(Vector2(0, -14), 22, base)
		draw_circle(Vector2(-7, -17), 2.2, Color("#17202A"))
		draw_circle(Vector2(7, -17), 2.2, Color("#17202A"))
		draw_arc(Vector2(0, -9), 5, 0.2, PI - 0.2, 12, accent, 2)
	if true_boss:
		var boss_name := boss_display_name()
		var boss_font_size := clampi(16 - maxi(0, boss_name.length() - 4), 11, 16)
		var boss_label_y := health_bar_y - 13.0
		# Draw a compact shadow first so long Chinese names stay readable over art.
		draw_string(ThemeDB.fallback_font, Vector2(-91, boss_label_y + 1), boss_name, HORIZONTAL_ALIGNMENT_CENTER, 182, boss_font_size, Color("#2A1808"))
		draw_string(ThemeDB.fallback_font, Vector2(-90, boss_label_y), boss_name, HORIZONTAL_ALIGNMENT_CENTER, 180, boss_font_size, Color("#FFE08A"))
	draw_arc(Vector2.ZERO, 17, 0, TAU, 24, accent, 3)
	if faction == "heroes":
		draw_circle(Vector2(0, faction_marker_y), 4, Color("#68D6FF"))
	else:
		draw_circle(Vector2(0, faction_marker_y), 4, Color("#FF6B60"))
	# HP bar
	draw_rect(Rect2(-24, health_bar_y, 48, 6), Color(0.08, 0.09, 0.1, 0.85), true)
	draw_rect(Rect2(-23, health_bar_y + 1.0, 46 * (hp / max_hp), 4), Color("#65D97B") if faction == "heroes" else Color("#EE6158"), true)
	if shield > 0:
		draw_arc(Vector2.ZERO, 28, 0, TAU, 24, Color("#80C8FF"), 3)
	if poison_time > 0:
		draw_circle(Vector2(23, -37), 5, Color("#C58DFF"))

func is_true_boss_unit() -> bool:
	return faction == "enemies" and enemy_type == "boss" and actor_data.has("boss_id")

func boss_display_name() -> String:
	return _name() if is_true_boss_unit() else ""

func draw_chibi_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _name() -> String:
	if faction == "heroes" and battle != null and battle.has_method("actor_display_name"):
		return battle.actor_display_name(actor_id)
	return actor_data.get("name", actor_id)

func _skill_name() -> String:
	return skill_data.get("name", "技能")

func _accent_color() -> Color:
	return Color(actor_data.get("accent", "FFFFFF"))

func _skill_color() -> Color:
	return Color(skill_data.get("color", "FFFFFF"))
