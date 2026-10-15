class_name CombatStats
extends RefCounted

var started_at := 0.0
var actors: Dictionary = {}
var resources := {"equipment": 0, "materials": 0, "auto_sold_count": 0, "auto_sold_gold": 0, "auto_dismantled_count": 0, "auto_dismantled_material": 0}

func reset(elapsed: float = 0.0) -> void:
	started_at = elapsed
	actors.clear()
	resources = {"equipment": 0, "materials": 0, "auto_sold_count": 0, "auto_sold_gold": 0, "auto_dismantled_count": 0, "auto_dismantled_material": 0}

func ensure_actor(id: String) -> Dictionary:
	if not actors.has(id):
		actors[id] = {"damage": 0.0, "basic": 0.0, "skill": 0.0, "effect": 0.0, "healing": 0.0, "taken": 0.0, "skills": 0, "kills": 0, "damage_sources": {}}
	elif not actors[id].has("damage_sources"):
		actors[id]["damage_sources"] = {}
	return actors[id]

func record_damage(source_id: String, target_id: String, amount: float, kind: String, damage_source_id: String = "") -> void:
	if amount <= 0.0:
		return
	if not source_id.is_empty():
		var row := ensure_actor(source_id)
		row.damage += amount
		var normalized_kind := kind if kind in ["basic", "skill", "effect"] else "skill"
		row[normalized_kind] += amount
		var source_key := damage_source_id if not damage_source_id.is_empty() else "basic" if normalized_kind == "basic" else "effect"
		if not row.damage_sources.has(source_key):
			row.damage_sources[source_key] = {"damage":0.0, "hits":0, "kind":normalized_kind}
		row.damage_sources[source_key].damage += amount
		row.damage_sources[source_key].hits += 1
	if not target_id.is_empty():
		ensure_actor(target_id).taken += amount

func record_heal(source_id: String, amount: float) -> void:
	ensure_actor(source_id).healing += amount

func record_skill(source_id: String) -> void:
	ensure_actor(source_id).skills += 1

func record_kill(source_id: String) -> void:
	ensure_actor(source_id).kills += 1

func snapshot(elapsed: float, tracked_ids: Array = []) -> Dictionary:
	var duration := maxf(1.0, elapsed - started_at)
	var copy := actors.duplicate(true)
	for id in tracked_ids:
		if not copy.has(id):
			copy[id] = {"damage": 0.0, "basic": 0.0, "skill": 0.0, "effect": 0.0, "healing": 0.0, "taken": 0.0, "skills": 0, "kills": 0, "damage_sources": {}}
	for id in copy:
		copy[id].dps = float(copy[id].damage) / duration
		copy[id].hps = float(copy[id].healing) / duration
		var actor_damage := maxf(1.0, float(copy[id].damage))
		for source_id in copy[id].get("damage_sources", {}):
			var source_row: Dictionary = copy[id].damage_sources[source_id]
			source_row.percent = float(source_row.damage) * 100.0 / actor_damage
			source_row.average = float(source_row.damage) / maxi(1, int(source_row.hits))
			source_row.dps = float(source_row.damage) / duration
	var team := {"damage": 0.0, "healing": 0.0, "taken": 0.0, "skills": 0, "kills": 0, "dps": 0.0, "hps": 0.0}
	var aggregate_ids: Array = tracked_ids if not tracked_ids.is_empty() else copy.keys()
	for id in aggregate_ids:
		var row: Dictionary = copy.get(id, {})
		team.damage += float(row.get("damage", 0.0))
		team.healing += float(row.get("healing", 0.0))
		team.taken += float(row.get("taken", 0.0))
		team.skills += int(row.get("skills", 0))
		team.kills += int(row.get("kills", 0))
	team.dps = team.damage / duration
	team.hps = team.healing / duration
	return {
		"duration": duration,
		"actors": copy,
		"team": team,
		"resources": resources.duplicate(true),
		"resources_per_minute": (resources.equipment + resources.materials) * 60.0 / duration,
		"equipment_per_minute": resources.equipment * 60.0 / duration
	}

