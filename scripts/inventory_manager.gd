class_name InventoryManager
extends Node

signal inventory_changed
signal equipment_changed(actor_id: String)
signal save_completed(path: String)

const SAVE_VERSION := "0.2A"
const SAVE_PATH := "user://wanjie_v02_save.json"
const TEST_SAVE_PATH := "user://wanjie_v02_test_save.json"
const HERO_IDS := ["zhao_yun", "liu_bei", "pikachu", "snorlax"]

var config: Dictionary
var items: Array = []
var equipped: Dictionary = {}
var capacity := 120
var save_path := SAVE_PATH

func setup(equipment_config: Dictionary) -> void:
	config = equipment_config
	capacity = int(config.get("rules", {}).get("inventory_capacity", 120))
	if "--equipment-test" in OS.get_cmdline_user_args():
		save_path = TEST_SAVE_PATH
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
	items.append(item.duplicate(true))
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
	if not equipped.has(actor_id):
		return false
	var item = find_item(instance_id)
	if item == null:
		return false
	var slot := target_slot if not target_slot.is_empty() else String(item.get("slot", ""))
	if slot not in item.get("compatible_slots", [item.get("slot", "")]):
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
	if not equipped.has(actor_id) or not equipped[actor_id].has(slot):
		return false
	if String(equipped[actor_id][slot]).is_empty():
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
	if not FileAccess.file_exists(save_path):
		ensure_equipment_layout()
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("version"):
		push_warning("存档格式无效，已忽略")
		return false
	items = parsed.get("items", [])
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
