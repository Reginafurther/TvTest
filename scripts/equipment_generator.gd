class_name EquipmentGenerator
extends RefCounted

var config: Dictionary
var loot_config: Dictionary
var special_config: Dictionary
var rng := RandomNumberGenerator.new()
var sequence := 0

func _init(equipment_config: Dictionary, loot_tables: Dictionary, seed_value: int = 0, specials: Dictionary = {}) -> void:
	config = equipment_config
	loot_config = loot_tables
	special_config = specials
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func generate(level: int, source: String, forced_quality: String = "", forced_slot: String = "", forced_template: String = "") -> Dictionary:
	var templates: Dictionary = config.get("templates", {})
	var candidates: Array = []
	for template_id in templates:
		var template: Dictionary = templates[template_id]
		if not forced_template.is_empty() and template_id != forced_template:
			continue
		if forced_slot.is_empty() or template.get("slot", "") == forced_slot or forced_slot in template.get("compatible_slots", []):
			candidates.append(template_id)
	if candidates.is_empty():
		return {}
	var template_id: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	var template: Dictionary = templates[template_id]
	var quality_id := forced_quality if not forced_quality.is_empty() else roll_quality(false)
	var quality: Dictionary = config.get("qualities", {}).get(quality_id, {})
	var base_stat: String = template.get("base_pool", ["attack"])[rng.randi_range(0, template.get("base_pool", ["attack"]).size() - 1)]
	var level_factor := 1.0 + maxf(0.0, level - 1) * 0.12
	var base_value := rng.randf_range(float(template.get("base_min", 1)), float(template.get("base_max", 2)))
	base_value *= level_factor * float(quality.get("base_multiplier", 1.0))
	var affix_count := rng.randi_range(int(quality.get("affix_min", 0)), int(quality.get("affix_max", 0)))
	var affixes := roll_affixes(level, quality, affix_count)
	sequence += 1
	var item := {
		"instance_id": make_instance_id(),
		"template_id": template_id,
		"name": quality.get("name", "") + "·" + template.get("name", "装备"),
		"slot": template.get("slot", "main_hand"),
		"compatible_slots": template.get("compatible_slots", [template.get("slot", "main_hand")]),
		"level": level,
		"quality": quality_id,
		"quality_rank": int(quality.get("rank", 0)),
		"base_stats": {base_stat: snappedf(base_value, 0.01)},
		"affixes": affixes,
		"source": source,
		"special_effects": roll_specials(quality_id)
	}
	return item

func roll_specials(quality_id: String) -> Array:
	if special_config.is_empty():
		return []
	var quality: Dictionary = config.get("qualities", {}).get(quality_id, {})
	var generation: Dictionary = special_config.get("generation", {})
	if int(quality.get("rank", 0)) < int(generation.get("min_quality_rank", 3)):
		return []
	# Red equipment follows the complete orange special-effect rule; its only
	# additional power is the separately stored fixed world affix.
	var chance := float(generation.get("orange_chance", 0.4)) if quality_id in ["orange", "red"] else float(generation.get("purple_chance", 0.18))
	if rng.randf() > chance:
		return []
	var ids: Array = special_config.get("effects", {}).keys()
	if ids.is_empty():
		return []
	return [ids[rng.randi_range(0, ids.size() - 1)]]

func roll_quality(test_mode: bool) -> String:
	var table: Dictionary = loot_config.get("grassland_crossing", {})
	var weights: Dictionary = table.get("test_quality_weights" if test_mode else "quality_weights", {})
	var total := 0.0
	for id in weights:
		total += float(weights[id])
	var roll := rng.randf() * total
	for id in weights:
		roll -= float(weights[id])
		if roll <= 0.0:
			return id
	return "white"

func roll_affixes(level: int, quality: Dictionary, count: int) -> Array:
	var available: Array = config.get("affixes", {}).keys()
	var result: Array = []
	for _index in range(mini(count, available.size())):
		var affix_id: String = weighted_affix(available)
		available.erase(affix_id)
		var affix: Dictionary = config.get("affixes", {}).get(affix_id, {})
		var raw := rng.randf_range(float(affix.get("min", 0)), float(affix.get("max", 0)))
		raw += maxf(0.0, level - 1) * float(affix.get("level_scale", 0))
		raw *= float(quality.get("value_multiplier", 1.0))
		result.append({"stat": affix_id, "value": snappedf(raw, 0.0001)})
	return result

func weighted_affix(available: Array) -> String:
	var total := 0.0
	for id in available:
		total += float(config.get("affixes", {}).get(id, {}).get("weight", 1))
	var roll := rng.randf() * total
	for id in available:
		roll -= float(config.get("affixes", {}).get(id, {}).get("weight", 1))
		if roll <= 0:
			return id
	return available[0]

func make_instance_id() -> String:
	return "%x-%x-%06x" % [int(Time.get_unix_time_from_system()), sequence, rng.randi() & 0xFFFFFF]

func combined_stats(item: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for stat in item.get("base_stats", {}):
		result[stat] = float(result.get(stat, 0)) + float(item.base_stats[stat])
	for affix in item.get("affixes", []):
		var stat: String = affix.get("stat", "")
		result[stat] = float(result.get(stat, 0)) + float(affix.get("value", 0))
	var world_affix = item.get("world_affix", {})
	if typeof(world_affix) == TYPE_DICTIONARY and not str(world_affix.get("stat", "")).is_empty():
		var stat := str(world_affix.stat)
		result[stat] = float(result.get(stat, 0)) + float(world_affix.get("value", 0.0))
	return result

