class_name InventoryManager
extends Node

signal inventory_changed
signal equipment_changed(actor_id: String)
signal save_completed(path: String)

const SAVE_VERSION := "0.6.1"
const SAVE_PATH := "user://wanjie_v061_inventory.json"
const TEST_SAVE_PATH := "user://wanjie_v061_test_inventory.json"
const HERO_IDS := ["zhang_fei", "dian_wei", "zhao_yun", "zhuge_liang", "liu_bei", "lu_bu", "pikachu", "snorlax", "gengar", "mewtwo"]

var config: Dictionary
var items: Array = []
var equipped: Dictionary = {}
var capacity := 120
var save_path := SAVE_PATH
var last_error := ""

func setup(equipment_config: Dictionary) -> void:
	config = equipment_config
	capacity = int(config.get("rules", {}).get("inventory_capacity", 120))
	for value in OS.get_cmdline_user_args():
		if str(value).begins_with("--v061-"):
			save_path = TEST_SAVE_PATH
			break
	ensure_equipment_layout()

func clear_test_save() -> void:
	if save_path == TEST_SAVE_PATH and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func ensure_equipment_layout() -> void:
	var slots: Array = config.get("slots", {}).keys()
	for actor_id in HERO_IDS:
		if not equipped.has(actor_id) or typeof(equipped[actor_id]) != TYPE_DICTIONARY:
			equipped[actor_id] = {}
		for slot in slots:
			if not equipped[actor_id].has(slot):
				equipped[actor_id][slot] = ""

func add_item(item: Dictionary, autosave: bool = true) -> bool:
	if items.size() >= capacity or item.is_empty():
		return false
	if find_item(item.get("instance_id", "")) != null:
		return false
	var stored := item.duplicate(true)
	stored["locked"] = bool(stored.get("locked", false))
	items.append(stored)
	inventory_changed.emit()
	if autosave:
		save_to_disk()
	return true

func find_item(instance_id: String):
	for item in items:
		if item.get("instance_id", "") == instance_id:
			return item
	return null

func equip_item(actor_id: String, instance_id: String, target_slot: String = "") -> bool:
	last_error = ""
	if not equipped.has(actor_id):
		last_error = "角色不存在或尚未初始化装备栏。"
		return false
	var item = find_item(instance_id)
	if item == null:
		last_error = "背包中找不到这件装备。"
		return false
	var slot := target_slot if not target_slot.is_empty() else String(item.get("slot", ""))
	if not equipped[actor_id].has(slot):
		last_error = "目标装备栏无效。"
		return false
	if slot not in item.get("compatible_slots", [item.get("slot", "")]):
		last_error = "%s不能穿戴到%s。" % [item.get("name", "该装备"), config.get("slots", {}).get(slot, slot)]
		return false
	# One unique instance may be equipped by only one actor and one slot.
	for owner_id in equipped:
		for occupied_slot in equipped[owner_id]:
			if equipped[owner_id][occupied_slot] == instance_id:
				equipped[owner_id][occupied_slot] = ""
				equipment_changed.emit(owner_id)
	equipped[actor_id][slot] = instance_id
	equipment_changed.emit(actor_id)
	inventory_changed.emit()
	save_to_disk()
	return true

func unequip_slot(actor_id: String, slot: String) -> bool:
	last_error = ""
	if not equipped.has(actor_id) or not equipped[actor_id].has(slot):
		last_error = "角色或装备栏不存在。"
		return false
	if String(equipped[actor_id][slot]).is_empty():
		last_error = "该装备栏当前为空。"
		return false
	equipped[actor_id][slot] = ""
	equipment_changed.emit(actor_id)
	inventory_changed.emit()
	save_to_disk()
	return true

func get_equipped_item(actor_id: String, slot: String):
	if not equipped.has(actor_id):
		return null
	return find_item(String(equipped[actor_id].get(slot, "")))

func item_owner(instance_id: String) -> String:
	for actor_id in equipped:
		if instance_id in equipped[actor_id].values():
			return actor_id
	return ""

func set_item_locked(instance_id: String, locked: bool) -> bool:
	var item = find_item(instance_id)
	if item == null:
		last_error = "背包中找不到这件装备。"
		return false
	item.set("locked", locked)
	inventory_changed.emit()
	save_to_disk()
	return true

func item_score(item: Dictionary, combat_role: String = "") -> float:
	var stats := item_stats(item)
	var weights := {"attack":5.0,"defense":3.0,"health":0.3,"crit_chance":300.0,"crit_damage":120.0,"attack_speed":180.0,"cooldown_reduction":180.0,"physical_damage":140.0,"elemental_damage":140.0,"life_regen":8.0}
	match combat_role:
		"tank": weights.merge({"attack":2.2,"defense":7.0,"health":0.7,"life_regen":14.0,"cooldown_reduction":130.0}, true)
		"healer": weights.merge({"attack":4.5,"defense":3.5,"health":0.45,"cooldown_reduction":300.0,"attack_speed":220.0,"life_regen":11.0}, true)
		"ranged_dps": weights.merge({"attack":5.8,"defense":1.8,"health":0.2,"crit_chance":360.0,"crit_damage":155.0,"elemental_damage":230.0,"cooldown_reduction":210.0}, true)
		"melee_dps": weights.merge({"attack":6.2,"defense":2.5,"health":0.28,"crit_chance":350.0,"physical_damage":230.0,"attack_speed":220.0}, true)
	var score := 0.0
	for stat_id in weights: score += float(stats.get(stat_id, 0.0)) * float(weights[stat_id])
	return score

func optimize_candidates(actor_id: String, min_quality_rank: int = 0, maximum: int = 3, combat_role: String = "") -> Array:
	var choices: Array = []
	var chosen_ids: Array = []
	if not equipped.has(actor_id):
		return choices
	for slot in equipped[actor_id]:
		var current = get_equipped_item(actor_id, slot)
		var current_score := item_score(current, combat_role) if current != null else 0.0
		var best_item
		var best_gain := 0.0
		for item in items:
			if bool(item.get("locked", false)):
				continue
			if str(item.get("instance_id", "")) in chosen_ids:
				continue
			if int(item.get("quality_rank", 0)) < min_quality_rank:
				continue
			var owner := item_owner(str(item.get("instance_id", "")))
			if not owner.is_empty() and owner != actor_id:
				continue
			if slot not in item.get("compatible_slots", [item.get("slot", "")]):
				continue
			var gain := item_score(item, combat_role) - current_score
			if gain > best_gain and str(item.get("instance_id", "")) != str(equipped[actor_id][slot]):
				best_gain = gain
				best_item = item
		if best_item != null:
			choices.append({"instance_id": best_item.instance_id, "slot": slot, "gain": best_gain, "name": best_item.get("name", "装备")})
			chosen_ids.append(str(best_item.instance_id))
	choices.sort_custom(func(a, b): return float(a.gain) > float(b.gain))
	if choices.size() > maximum:
		choices.resize(maximum)
	return choices

func apply_optimization(actor_id: String, choices: Array) -> int:
	var applied := 0
	for choice in choices.slice(0, 3):
		var item = find_item(str(choice.instance_id))
		if item == null or bool(item.get("locked", false)):
			continue
		if item_owner(str(choice.instance_id)) not in ["", actor_id]:
			continue
		if equip_item(actor_id, str(choice.instance_id), str(choice.slot)):
			applied += 1
	return applied

func get_actor_stats(actor_id: String, excluding_slot: String = "") -> Dictionary:
	var totals: Dictionary = {}
	if not equipped.has(actor_id):
		return totals
	for slot in equipped[actor_id]:
		if slot == excluding_slot:
			continue
		var item = get_equipped_item(actor_id, slot)
		if item != null:
			merge_stats(totals, item_stats(item))
	return totals

func get_actor_specials(actor_id: String) -> Array:
	var result: Array = []
	if not equipped.has(actor_id):
		return result
	for slot in equipped[actor_id]:
		var item = get_equipped_item(actor_id, slot)
		if item != null:
			for effect in item.get("special_effects", []):
				if effect not in result:
					result.append(effect)
	return result

func preview_stats(actor_id: String, item: Dictionary, target_slot: String = "") -> Dictionary:
	var slot := target_slot if not target_slot.is_empty() else String(item.get("slot", ""))
	var totals := get_actor_stats(actor_id, slot)
	merge_stats(totals, item_stats(item))
	return totals

func item_stats(item: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	for stat in item.get("base_stats", {}):
		totals[stat] = float(totals.get(stat, 0)) + float(item.base_stats[stat])
	for affix in item.get("affixes", []):
		var stat: String = affix.get("stat", "")
		totals[stat] = float(totals.get(stat, 0)) + float(affix.get("value", 0))
	return totals

func merge_stats(target: Dictionary, addition: Dictionary) -> void:
	for stat in addition:
		target[stat] = float(target.get(stat, 0)) + float(addition[stat])

func save_to_disk() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"items": items,
		"equipped": equipped
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入存档: " + save_path)
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	save_completed.emit(save_path)
	return true

func load_from_disk() -> bool:
	var source_path := save_path
	if not FileAccess.file_exists(source_path):
		ensure_equipment_layout()
		return false
	var file := FileAccess.open(source_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("version", "")) != SAVE_VERSION:
		push_warning("存档格式无效，已忽略")
		return false
	items = parsed.get("items", [])
	for item in items:
		item["locked"] = bool(item.get("locked", false))
	equipped = parsed.get("equipped", {})
	remove_broken_references()
	ensure_equipment_layout()
	inventory_changed.emit()
	return true

func remove_broken_references() -> void:
	var known: Dictionary = {}
	for item in items:
		known[item.get("instance_id", "")] = true
	for actor_id in equipped:
		if typeof(equipped[actor_id]) != TYPE_DICTIONARY:
			continue
		for slot in equipped[actor_id]:
			var id: String = equipped[actor_id][slot]
			if not id.is_empty() and not known.has(id):
				equipped[actor_id][slot] = ""

func all_ids_unique() -> bool:
	var seen: Dictionary = {}
	for item in items:
		var id: String = item.get("instance_id", "")
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
