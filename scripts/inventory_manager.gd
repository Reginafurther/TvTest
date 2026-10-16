class_name InventoryManager
extends Node

signal inventory_changed
signal equipment_changed(actor_id: String)
signal save_completed(path: String)

const SAVE_VERSION := "0.8"
const SAVE_PATH := "user://wanjie_v08_inventory.json"
const LEGACY_SAVE_PATH := "user://wanjie_v07_inventory.json"
const LEGACY_V061_SAVE_PATH := "user://wanjie_v061_inventory.json"
const MIGRATION_BACKUP_PATH := "user://wanjie_v07_inventory.pre_v08_backup.json"
const AFFIX_MIGRATION_BACKUP_PATH := "user://wanjie_v08_inventory.pre_affix_v2_backup.json"
const EFFECT_REMOVAL_BACKUP_PATH := "user://wanjie_v08_inventory.pre_effect_removal_backup.json"
const BALANCE_MIGRATION_BACKUP_PATH := "user://wanjie_v08_inventory.pre_balance_v3_backup.json"
const TEST_SAVE_PATH := "user://wanjie_v08_test_inventory.json"
const RESET_MARKER_PATH := "user://wanjie_reset_marker.json"
const HERO_IDS := ["zhang_fei", "dian_wei", "zhao_yun", "zhuge_liang", "liu_bei", "lu_bu", "guan_yu", "huang_zhong", "diao_chan", "zhou_yu", "pikachu", "snorlax", "gengar", "mewtwo", "bulbasaur", "charmander", "squirtle", "lucario", "gardevoir", "dragonite", "chen_motong", "chu_zihang", "yabuki_sakura", "lu_mingfei", "lu_mingze", "caesar", "eri_uesugi", "minamoto_chisei", "minamoto_chime", "zero", "blood_river", "iron_guard", "broken_dream", "divine_harmony", "plain_question", "nine_spirits", "varian_wrynn", "anduin_wrynn", "thrall", "arthas_menethil", "illidan_stormrage", "jaina_proudmoore", "guo_jing", "huang_rong", "yang_guo", "xiaolongnu", "zhang_wuji", "zhou_zhiruo", "qiao_feng", "duan_yu", "linghu_chong", "ren_yingying", "qin_gai_nie", "qin_wei_zhuang", "qin_jing_tianming", "qin_xiang_shaoyu", "qin_gao_jianli", "qin_xue_nv", "qin_duanmu_rong", "qin_shaosiming", "qin_xiaomeng", "qin_zhang_liang", "naruto_uzumaki", "naruto_sasuke", "naruto_sakura", "naruto_kakashi", "naruto_itachi", "naruto_shikamaru", "naruto_hinata", "naruto_gaara", "naruto_jiraiya", "naruto_tsunade", "hy_long_ying", "hy_wu_zhao", "hy_kou_zhong", "hy_xu_ziling", "hy_wan_wan", "hy_fa_ming", "hy_yan_fei", "hy_sun_en", "hy_ling_donglai", "hy_lang_fanyun"]
const FENGYUN_HERO_IDS := ["fy_nie_feng", "fy_bu_jingyun", "fy_wuming", "fy_sword_saint", "fy_wu_wudi", "fy_xiao_wu", "fy_duan_lang", "fy_di_er_meng", "fy_jian_chen", "fy_di_shitian"]
const ALL_HERO_IDS := HERO_IDS + FENGYUN_HERO_IDS
const AFFIX_CONFIG_VERSION := 2
const EQUIPMENT_BALANCE_VERSION := 3

var config: Dictionary
var items: Array = []
var equipped: Dictionary = {}
var capacity := 300
var save_path := SAVE_PATH
var last_error := ""
var affix_config_version := AFFIX_CONFIG_VERSION
var equipment_balance_version := EQUIPMENT_BALANCE_VERSION

func setup(equipment_config: Dictionary) -> void:
	config = equipment_config
	capacity = int(config.get("rules", {}).get("inventory_capacity", 300))
	for value in OS.get_cmdline_user_args():
		if str(value).begins_with("--v061-") or str(value).begins_with("--v07-") or str(value).begins_with("--v08-") or str(value).begins_with("--v081-") or str(value).begins_with("--v09-") or str(value).begins_with("--v10-"):
			save_path = TEST_SAVE_PATH
			break
	ensure_equipment_layout()

func clear_test_save() -> void:
	if save_path == TEST_SAVE_PATH and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func ensure_equipment_layout() -> void:
	var slots: Array = config.get("slots", {}).keys()
	for actor_id in ALL_HERO_IDS:
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
	stored.erase("special_effects")
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

func equip_item(actor_id: String, instance_id: String, target_slot: String = "", autosave: bool = true) -> bool:
	last_error = ""
	if not equipped.has(actor_id):
		last_error = "角色不存在或尚未初始化装备栏。"
		return false
	if _item_instance_count(instance_id) != 1:
		last_error = "装备实例ID无效或不唯一，已拒绝穿戴。"
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
	var occupied_locations: Array = []
	for owner_id in equipped:
		for occupied_slot in equipped[owner_id]:
			if equipped[owner_id][occupied_slot] == instance_id:
				occupied_locations.append({"actor_id": str(owner_id), "slot": str(occupied_slot)})
	if occupied_locations.size() > 1:
		last_error = "装备实例已出现在多个穿戴位置，已拒绝修改。"
		return false
	if not occupied_locations.is_empty() and str(occupied_locations[0].actor_id) != actor_id:
		last_error = "该装备正由其他角色穿戴，请先从原角色卸下。"
		return false
	if not occupied_locations.is_empty() and str(occupied_locations[0].slot) == slot:
		return true
	# All validation happens before mutation. Moving an item between the same
	# actor's compatible slots is allowed, but cross-actor transfer is not.
	if not occupied_locations.is_empty():
		equipped[actor_id][str(occupied_locations[0].slot)] = ""
	equipped[actor_id][slot] = instance_id
	equipment_changed.emit(actor_id)
	inventory_changed.emit()
	if autosave: save_to_disk()
	return true

func available_items_for_actor(actor_id: String, include_other_equipped: bool = false, compatible_slot: String = "") -> Array:
	var result: Array = []
	for item in items:
		var instance_id := str(item.get("instance_id", ""))
		var owner := item_owner(instance_id)
		if not include_other_equipped and not owner.is_empty() and owner != actor_id:
			continue
		if not compatible_slot.is_empty() and compatible_slot not in item.get("compatible_slots", [item.get("slot", "")]):
			continue
		result.append(item)
	return result

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

func can_swap_actor_equipment(first_actor: String, second_actor: String) -> bool:
	last_error = ""
	if first_actor.is_empty() or second_actor.is_empty() or first_actor == second_actor:
		last_error = "装备交换需要两个不同角色。"
		return false
	if not equipped.has(first_actor) or not equipped.has(second_actor):
		last_error = "角色装备栏尚未初始化。"
		return false
	var proposed: Dictionary = equipped.duplicate(true)
	proposed[first_actor] = equipped[second_actor].duplicate(true)
	proposed[second_actor] = equipped[first_actor].duplicate(true)
	var seen: Dictionary = {}
	for actor_id in proposed:
		var mapping: Dictionary = proposed[actor_id]
		for slot in config.get("slots", {}):
			if not mapping.has(slot):
				last_error = "%s缺少装备栏%s。" % [actor_id, slot]
				return false
			var instance_id := str(mapping[slot])
			if instance_id.is_empty(): continue
			if seen.has(instance_id) or _item_instance_count(instance_id) != 1:
				last_error = "装备实例ID重复或不存在，交换已取消。"
				return false
			var item = find_item(instance_id)
			if item == null or slot not in item.get("compatible_slots", [item.get("slot", "")]):
				last_error = "装备与目标栏位不兼容，交换已取消。"
				return false
			seen[instance_id] = true
	return true

func swap_actor_equipment(first_actor: String, second_actor: String, autosave: bool = true) -> bool:
	if not can_swap_actor_equipment(first_actor, second_actor): return false
	var first_mapping: Dictionary = equipped[first_actor].duplicate(true)
	equipped[first_actor] = equipped[second_actor].duplicate(true)
	equipped[second_actor] = first_mapping
	equipment_changed.emit(first_actor)
	equipment_changed.emit(second_actor)
	inventory_changed.emit()
	if autosave: save_to_disk()
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

func item_equipped_slot(instance_id: String, actor_id: String = "") -> String:
	for owner_id in equipped:
		if not actor_id.is_empty() and str(owner_id) != actor_id:
			continue
		for slot in equipped[owner_id]:
			if str(equipped[owner_id][slot]) == instance_id:
				return str(slot)
	return ""

func _item_instance_count(instance_id: String) -> int:
	var count := 0
	for item in items:
		if str(item.get("instance_id", "")) == instance_id:
			count += 1
	return count

func set_item_locked(instance_id: String, locked: bool) -> bool:
	var item = find_item(instance_id)
	if item == null:
		last_error = "背包中找不到这件装备。"
		return false
	item.set("locked", locked)
	inventory_changed.emit()
	save_to_disk()
	return true

func item_score(item: Dictionary, combat_role: String = "", scoring_context: Dictionary = {}) -> float:
	var stats := item_stats(item)
	if combat_role == "tank":
		var base_health := maxf(1.0, float(scoring_context.get("base_health", 1.0)))
		var boss_attack := maxf(1.0, float(scoring_context.get("boss_attack", 1.0)))
		return (
			float(stats.get("health", 0.0)) / 1.5 / base_health * 100.0
			+ float(stats.get("defense", 0.0)) / boss_attack * 100.0
			+ float(stats.get("damage_reduction", 0.0)) * 100.0
			+ float(stats.get("cooldown_reduction", 0.0)) * 50.0
		)
	var weights := {"attack":5.0,"defense":3.0,"health":0.3,"crit_chance":300.0,"crit_damage":120.0,"attack_speed":180.0,"cooldown_reduction":180.0,"physical_damage":140.0,"elemental_damage":140.0,"final_damage":260.0,"damage_reduction":240.0,"healing_effect":180.0}
	match combat_role:
		"healer": weights.merge({"attack":4.5,"defense":3.5,"health":0.45,"cooldown_reduction":300.0,"attack_speed":220.0,"healing_effect":520.0}, true)
		"ranged_dps": weights.merge({"attack":5.8,"defense":1.8,"health":0.2,"crit_chance":360.0,"crit_damage":155.0,"elemental_damage":230.0,"cooldown_reduction":210.0}, true)
		"melee_dps": weights.merge({"attack":6.2,"defense":2.5,"health":0.28,"crit_chance":350.0,"physical_damage":230.0,"attack_speed":220.0}, true)
	var score := 0.0
	for stat_id in weights: score += float(stats.get(stat_id, 0.0)) * float(weights[stat_id])
	return score

func optimize_candidates(actor_id: String, min_quality_rank: int = 0, maximum: int = 9, combat_role: String = "", scoring_context: Dictionary = {}) -> Array:
	var choices: Array = []
	var chosen_ids: Array = []
	if not equipped.has(actor_id):
		return choices
	for slot in equipped[actor_id]:
		if slot in ["ring_1", "ring_2"]:
			continue
		var current = get_equipped_item(actor_id, slot)
		if current != null and bool(current.get("locked", false)):
			continue
		var current_score := item_score(current, combat_role, scoring_context) if current != null else 0.0
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
			var gain := item_score(item, combat_role, scoring_context) - current_score
			if gain > best_gain and str(item.get("instance_id", "")) != str(equipped[actor_id][slot]):
				best_gain = gain
				best_item = item
		if best_item != null:
			choices.append({"instance_id": best_item.instance_id, "slot": slot, "gain": best_gain, "name": best_item.get("name", "装备"), "combat_role": combat_role, "scoring_context":scoring_context.duplicate(true)})
			chosen_ids.append(str(best_item.instance_id))
	choices.append_array(_optimize_ring_pair(actor_id, min_quality_rank, combat_role, scoring_context))
	choices.sort_custom(func(a, b): return float(a.gain) > float(b.gain))
	if choices.size() > maximum:
		choices.resize(maximum)
	return choices

func _optimize_ring_pair(actor_id: String, min_quality_rank: int, combat_role: String, scoring_context: Dictionary = {}) -> Array:
	var slots := ["ring_1", "ring_2"]
	var current_ids := [str(equipped[actor_id].get("ring_1", "")), str(equipped[actor_id].get("ring_2", ""))]
	var current_items := [find_item(current_ids[0]), find_item(current_ids[1])]
	var options: Array = [null]
	for item in available_items_for_actor(actor_id):
		var compatible: Array = item.get("compatible_slots", [item.get("slot", "")])
		if "ring_1" not in compatible and "ring_2" not in compatible:
			continue
		var instance_id := str(item.get("instance_id", ""))
		var is_current := instance_id in current_ids
		if int(item.get("quality_rank", 0)) < min_quality_rank and not is_current:
			continue
		if bool(item.get("locked", false)) and not is_current:
			continue
		options.append(item)
	var best_items: Array = current_items.duplicate()
	var best_score := _pair_score(best_items, combat_role, scoring_context)
	var best_stability := 2
	for left in options:
		if not _ring_option_valid(left, "ring_1", current_items[0]):
			continue
		for right in options:
			if not _ring_option_valid(right, "ring_2", current_items[1]):
				continue
			if left != null and right != null and str(left.get("instance_id", "")) == str(right.get("instance_id", "")):
				continue
			var proposal := [left, right]
			var score := _pair_score(proposal, combat_role, scoring_context)
			var stability := int(_item_id(left) == current_ids[0]) + int(_item_id(right) == current_ids[1])
			if score > best_score + 0.0001 or (is_equal_approx(score, best_score) and stability > best_stability):
				best_items = proposal
				best_score = score
				best_stability = stability
	var old_score := _pair_score(current_items, combat_role, scoring_context)
	if best_score <= old_score + 0.0001:
		return []
	var result: Array = []
	for index in range(2):
		var next_item = best_items[index]
		var next_id := _item_id(next_item)
		if next_id.is_empty() or next_id == current_ids[index]:
			continue
		var replaced_score := item_score(current_items[index], combat_role, scoring_context) if current_items[index] != null else 0.0
		result.append({"instance_id": next_id, "slot": slots[index], "gain": item_score(next_item, combat_role, scoring_context) - replaced_score, "name": next_item.get("name", "戒指"), "pair_gain": best_score - old_score, "combat_role": combat_role, "scoring_context":scoring_context.duplicate(true)})
	return result

func _ring_option_valid(item, slot: String, current) -> bool:
	if current != null and bool(current.get("locked", false)):
		return _item_id(item) == _item_id(current)
	if item == null:
		return true
	return slot in item.get("compatible_slots", [item.get("slot", "")])

func _item_id(item) -> String:
	return "" if item == null else str(item.get("instance_id", ""))

func _pair_score(pair: Array, combat_role: String, scoring_context: Dictionary = {}) -> float:
	var score := 0.0
	for item in pair:
		if item != null:
			score += item_score(item, combat_role, scoring_context)
	return score

func apply_optimization(actor_id: String, choices: Array) -> int:
	last_error = ""
	if not equipped.has(actor_id) or choices.is_empty():
		return 0
	var original: Dictionary = equipped[actor_id].duplicate(true)
	var final_mapping: Dictionary = original.duplicate(true)
	var choice_ids: Dictionary = {}
	var choice_slots: Dictionary = {}
	for choice in choices:
		var instance_id := str(choice.get("instance_id", ""))
		var target_slot := str(choice.get("slot", ""))
		var item = find_item(instance_id)
		if item == null or _item_instance_count(instance_id) != 1 or bool(item.get("locked", false)):
			last_error = "优化方案包含不存在、重复或已锁定的装备。"
			return 0
		if target_slot in choice_slots or instance_id in choice_ids or not final_mapping.has(target_slot):
			last_error = "优化方案包含重复装备或重复栏位。"
			return 0
		if target_slot not in item.get("compatible_slots", [item.get("slot", "")]):
			last_error = "优化方案包含不兼容的装备栏。"
			return 0
		if item_owner(instance_id) not in ["", actor_id]:
			last_error = "优化方案引用了其他角色正在穿戴的装备。"
			return 0
		var target_item = find_item(str(original.get(target_slot, "")))
		if target_item != null and bool(target_item.get("locked", false)) and str(target_item.get("instance_id", "")) != instance_id:
			last_error = "优化方案试图替换已锁定装备。"
			return 0
		choice_ids[instance_id] = true
		choice_slots[target_slot] = true
	for slot in final_mapping:
		if str(final_mapping[slot]) in choice_ids:
			final_mapping[slot] = ""
	for choice in choices:
		final_mapping[str(choice.slot)] = str(choice.instance_id)
	if not _mapping_is_unique(final_mapping):
		last_error = "优化后的装备映射存在重复实例。"
		return 0
	if not _all_equipped_instances_unique_with(actor_id, final_mapping):
		last_error = "优化后的全局装备映射存在重复实例。"
		return 0
	var combat_role := str(choices[0].get("combat_role", ""))
	var scoring_context: Dictionary = choices[0].get("scoring_context", {})
	if _mapping_score(final_mapping, combat_role, scoring_context) + 0.0001 < _mapping_score(original, combat_role, scoring_context):
		last_error = "优化方案会降低综合装备评分，已取消。"
		return 0
	equipped[actor_id] = final_mapping
	equipment_changed.emit(actor_id)
	inventory_changed.emit()
	save_to_disk()
	return choices.size()

func _mapping_is_unique(mapping: Dictionary) -> bool:
	var seen: Dictionary = {}
	for slot in mapping:
		var instance_id := str(mapping[slot])
		if instance_id.is_empty():
			continue
		if seen.has(instance_id):
			return false
		seen[instance_id] = true
	return true

func _mapping_score(mapping: Dictionary, combat_role: String, scoring_context: Dictionary = {}) -> float:
	var score := 0.0
	for slot in mapping:
		var item = find_item(str(mapping[slot]))
		if item != null:
			score += item_score(item, combat_role, scoring_context)
	return score

func _all_equipped_instances_unique_with(replaced_actor: String = "", replacement: Dictionary = {}) -> bool:
	var seen: Dictionary = {}
	for actor_id in equipped:
		var mapping: Dictionary = replacement if str(actor_id) == replaced_actor else equipped[actor_id]
		for slot in mapping:
			var instance_id := str(mapping[slot])
			if instance_id.is_empty():
				continue
			if seen.has(instance_id):
				return false
			seen[instance_id] = true
	return true

func equipped_instances_unique() -> bool:
	return _all_equipped_instances_unique_with()

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
	var world_affix = item.get("world_affix", {})
	if typeof(world_affix) == TYPE_DICTIONARY and not str(world_affix.get("stat", "")).is_empty():
		var stat := str(world_affix.stat)
		totals[stat] = float(totals.get(stat, 0)) + float(world_affix.get("value", 0.0))
	return totals

func merge_stats(target: Dictionary, addition: Dictionary) -> void:
	for stat in addition:
		target[stat] = float(target.get(stat, 0)) + float(addition[stat])

func save_to_disk() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"affix_config_version": AFFIX_CONFIG_VERSION,
		"equipment_balance_version": EQUIPMENT_BALANCE_VERSION,
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

func reset_to_new_game() -> bool:
	items = []
	equipped = {}
	ensure_equipment_layout()
	inventory_changed.emit()
	for actor_id in equipped: equipment_changed.emit(actor_id)
	return save_to_disk()

func load_from_disk() -> bool:
	var source_path := save_path
	if not FileAccess.file_exists(source_path) and save_path == SAVE_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_SAVE_PATH):
		if not FileAccess.file_exists(MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH), ProjectSettings.globalize_path(MIGRATION_BACKUP_PATH))
		source_path = LEGACY_SAVE_PATH
	elif not FileAccess.file_exists(source_path) and save_path == SAVE_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_V061_SAVE_PATH):
		source_path = LEGACY_V061_SAVE_PATH
	if not FileAccess.file_exists(source_path):
		ensure_equipment_layout()
		return false
	var file := FileAccess.open(source_path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or str(parsed.get("version", "")) not in [SAVE_VERSION, "0.7", "0.6.1"]:
		push_warning("存档格式无效，已忽略")
		return false
	items = parsed.get("items", [])
	var removed_legacy_effects := false
	for item in items:
		if item.has("special_effects"):
			removed_legacy_effects = true
			item.erase("special_effects")
	if removed_legacy_effects and save_path == SAVE_PATH and not FileAccess.file_exists(EFFECT_REMOVAL_BACKUP_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(EFFECT_REMOVAL_BACKUP_PATH))
	affix_config_version = int(parsed.get("affix_config_version", 1))
	var upgraded_affix_config := affix_config_version < AFFIX_CONFIG_VERSION
	if upgraded_affix_config:
		if save_path == SAVE_PATH and not FileAccess.file_exists(AFFIX_MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(AFFIX_MIGRATION_BACKUP_PATH))
		migrate_legacy_life_regen_affixes()
		affix_config_version = AFFIX_CONFIG_VERSION
	equipment_balance_version = int(parsed.get("equipment_balance_version", 2))
	var upgraded_equipment_balance := equipment_balance_version < EQUIPMENT_BALANCE_VERSION
	if upgraded_equipment_balance:
		if save_path == SAVE_PATH and not FileAccess.file_exists(BALANCE_MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(BALANCE_MIGRATION_BACKUP_PATH))
		migrate_equipment_balance_v3()
		equipment_balance_version = EQUIPMENT_BALANCE_VERSION
	for item in items:
		item["locked"] = bool(item.get("locked", false))
	equipped = parsed.get("equipped", {})
	remove_broken_references()
	ensure_equipment_layout()
	inventory_changed.emit()
	if upgraded_affix_config or removed_legacy_effects or upgraded_equipment_balance:
		save_to_disk()
	return true

func migrate_equipment_balance_v3() -> bool:
	var changed := false
	for item in items:
		var level := maxi(1, int(item.get("level", 1)))
		var quality: Dictionary = config.get("qualities", {}).get(str(item.get("quality", "white")), {})
		var value_multiplier := float(quality.get("value_multiplier", 1.0))
		var base_stats = item.get("base_stats", {})
		if typeof(base_stats) == TYPE_DICTIONARY and base_stats.has("defense"):
			base_stats.defense = snappedf(float(base_stats.defense) * float(config.get("rules", {}).get("defense_base_multiplier", 0.45)), 0.01)
			changed = true
		for affix in item.get("affixes", []):
			var stat := str(affix.get("stat", ""))
			if stat not in ["health", "defense"]: continue
			var old_min := (10.0 + (level - 1) * 1.8) * value_multiplier if stat == "health" else (1.0 + (level - 1) * 0.28) * value_multiplier
			var old_max := (24.0 + (level - 1) * 1.8) * value_multiplier if stat == "health" else (3.5 + (level - 1) * 0.28) * value_multiplier
			var percentile := clampf((float(affix.get("value", old_min)) - old_min) / maxf(0.0001, old_max - old_min), 0.0, 1.0)
			var cfg: Dictionary = config.affixes[stat]
			var new_min := (float(cfg.min) + (level - 1) * float(cfg.min_level_scale)) * value_multiplier
			var new_max := (float(cfg.max) + (level - 1) * float(cfg.max_level_scale)) * value_multiplier
			affix.value = snappedf(lerpf(new_min, new_max, percentile), 0.0001)
			changed = true
	return changed

func migrate_legacy_life_regen_affixes() -> bool:
	var changed := false
	for item in items:
		var base_stats = item.get("base_stats", {})
		if typeof(base_stats) == TYPE_DICTIONARY and base_stats.has("life_regen"):
			base_stats["healing_effect"] = float(base_stats.get("healing_effect", 0.0)) + legacy_regen_to_healing_effect(float(base_stats.life_regen))
			base_stats.erase("life_regen")
			changed = true
		for affix in item.get("affixes", []):
			if str(affix.get("stat", "")) == "life_regen":
				affix["stat"] = "healing_effect"
				affix["value"] = legacy_regen_to_healing_effect(float(affix.get("value", 0.0)))
				changed = true
	return changed

func legacy_regen_to_healing_effect(value: float) -> float:
	# Legacy values were flat HP/tick (commonly 0.8–4.0), not percentages.
	# Converting at two percentage points per legacy point preserves affix tier
	# without ever interpreting a value such as 2 as +200% healing.
	return snappedf(clampf(value * 0.02, 0.0, 0.12), 0.0001)

func remove_broken_references() -> void:
	var known: Dictionary = {}
	var worn: Dictionary = {}
	for item in items:
		known[item.get("instance_id", "")] = true
	for actor_id in equipped:
		if typeof(equipped[actor_id]) != TYPE_DICTIONARY:
			continue
		for slot in equipped[actor_id]:
			var id: String = equipped[actor_id][slot]
			if not id.is_empty() and not known.has(id):
				equipped[actor_id][slot] = ""
			elif not id.is_empty() and worn.has(id):
				# Repair legacy/corrupt saves deterministically so one instance can
				# never remain equipped in two positions after loading.
				equipped[actor_id][slot] = ""
			elif not id.is_empty():
				worn[id] = true

func all_ids_unique() -> bool:
	var seen: Dictionary = {}
	for item in items:
		var id: String = item.get("instance_id", "")
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true
