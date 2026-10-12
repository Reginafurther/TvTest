class_name CraftingManager
extends RefCounted

var inventory
var progression
var equipment_config: Dictionary
var generator
var pending: Dictionary = {}

func setup(inv, progress, config: Dictionary, item_generator) -> void:
	inventory = inv
	progression = progress
	equipment_config = config
	generator = item_generator

func is_equipped(instance_id: String) -> bool:
	for actor_id in inventory.equipped:
		for slot in inventory.equipped[actor_id]:
			if inventory.equipped[actor_id][slot] == instance_id:
				return true
	return false

func dismantle(instance_id: String) -> int:
	var item = inventory.find_item(instance_id)
	if item == null or is_equipped(instance_id):
		return 0
	var reward := maxi(1, (int(item.quality_rank) + 1) * 4 + int(item.level) * 2)
	var index: int = inventory.items.find(item)
	if index < 0:
		return 0
	inventory.items.remove_at(index)
	progression.add_material("salvage_dust", reward)
	inventory.inventory_changed.emit()
	inventory.save_to_disk()
	return reward

func begin_reroll(instance_id: String, affix_index: int) -> Dictionary:
	var item = inventory.find_item(instance_id)
	if item == null or affix_index < 0 or affix_index >= item.get("affixes", []).size():
		return {}
	var cost := 8 + int(item.level) * 2 + int(item.quality_rank) * 5
	if not progression.spend_material("salvage_dust", cost):
		return {}
	var quality: Dictionary = equipment_config.qualities.get(item.quality, {})
	var candidate: Array = generator.roll_affixes(int(item.level), quality, 1)
	if candidate.is_empty():
		progression.add_material("salvage_dust", cost)
		return {}
	pending = {"instance_id": instance_id, "index": affix_index, "old": item.affixes[affix_index].duplicate(true), "candidate": candidate[0], "cost": cost}
	return pending.duplicate(true)

func resolve_reroll(accept_new: bool) -> bool:
	if pending.is_empty():
		return false
	var item = inventory.find_item(pending.instance_id)
	if item == null:
		pending.clear()
		return false
	if accept_new:
		item.affixes[int(pending.index)] = pending.candidate.duplicate(true)
		for actor_id in inventory.equipped:
			if pending.instance_id in inventory.equipped[actor_id].values():
				inventory.equipment_changed.emit(actor_id)
	inventory.inventory_changed.emit()
	inventory.save_to_disk()
	pending.clear()
	return true
