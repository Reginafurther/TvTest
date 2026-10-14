class_name AdventureManager
extends Node

signal changed
signal encounter_notice(message: String)

var battle
var config: Dictionary = {}
var event_clock := 0.0
var active_rift: Dictionary = {}
var active_encounter: Dictionary = {}

func setup(owner_battle) -> void:
	battle = owner_battle
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/adventure.json"))
	if typeof(config) != TYPE_DICTIONARY: config = {}
	var v08 = JSON.parse_string(FileAccess.get_file_as_string("res://data/v08_content.json"))
	if typeof(v08) == TYPE_DICTIONARY:
		config.rift.worlds.merge(v08.get("rift_worlds", {}), true)
	active_encounter = battle.progression.encounter_state.get("active", {}).duplicate(true)
	if not active_encounter.is_empty():
		if str(active_encounter.get("type", "")) == "wandering_merchant":
			active_encounter.remaining = maxf(0.0, float(battle.progression.encounter_state.get("merchant_expiry", 0)) - Time.get_unix_time_from_system())
			if float(active_encounter.remaining) <= 0.0: active_encounter.clear()
		else:
			# Combat encounters are never recreated from a save: doing so could
			# duplicate their one-time reward. Record interruption and resume main combat.
			var interrupted_id := str(active_encounter.get("type", ""))
			battle.progression.encounter_counts[interrupted_id] = int(battle.progression.encounter_counts.get(interrupted_id, 0)) + 1
			battle.progression.encounter_log.push_front({"id":interrupted_id,"name":config.encounters.types.get(interrupted_id, {}).get("name", interrupted_id),"stage":battle.progression.completed_stages.size(),"time":int(Time.get_unix_time_from_system()),"success":false,"reward":{}})
			active_encounter.clear()
		if active_encounter.is_empty():
			battle.progression.encounter_state.active = {}
			battle.progression.save_to_disk()

func main_stage_cap() -> int:
	var configured_max := 0
	for map_id in battle.worlds_config.get("maps", {}):
		configured_max = maxi(configured_max, int(battle.worlds_config.maps[map_id].get("global_stage", 0)))
	return mini(configured_max, battle.progression.completed_stages.size())

func rift_world_unlocked(world_id: String) -> bool:
	var world: Dictionary = config.get("rift", {}).get("worlds", {}).get(world_id, {})
	return not world.is_empty() and battle.progression.is_stage_complete(int(world.get("required_stage", 9999)))

func can_challenge_rift(world_id: String, floor: int) -> bool:
	if not rift_world_unlocked(world_id) or floor < 1 or floor > main_stage_cap(): return false
	var state: Dictionary = battle.progression.rift_progress.get(world_id, {})
	return floor <= int(state.get("highest_clear", 0)) + 1

func rift_affix_ids(floor: int, world_id: String = "") -> Array[String]:
	var available: Array[String] = []
	var pool: Array = config.rift.worlds.get(world_id, {}).get("affix_pool", [])
	for id in config.get("rift", {}).get("affixes", {}):
		if (pool.is_empty() or id in pool) and floor >= int(config.rift.affixes[id].get("unlock_floor", 1)): available.append(str(id))
	var count := mini(3, 1 + floor / 7)
	var result: Array[String] = []
	for index in range(mini(count, available.size())):
		result.append(available[(floor + index * 3) % available.size()])
	return result

func rift_profile(world_id: String, floor: int) -> Dictionary:
	var world: Dictionary = config.rift.worlds.get(world_id, {})
	if world.is_empty(): return {}
	var base: Dictionary = battle.actors.get(str(world.boss_actor), {})
	var growth: Dictionary = config.rift.growth
	var n := float(maxi(0, floor - 1))
	var health_scale := 1.0 + n * float(growth.health_linear) + n * n * float(growth.health_quadratic)
	var attack_scale := 1.0 + n * float(growth.attack_linear) + n * n * float(growth.attack_quadratic)
	var defense_scale := 1.0 + n * float(growth.defense_linear) + n * n * float(growth.defense_quadratic)
	return {"name":"%s · 第%d层" % [world.boss_name, floor], "health":float(base.get("max_hp", 1000)) * health_scale, "attack":float(base.get("attack", 50)) * attack_scale, "defense":float(base.get("defense", 20)) * defense_scale, "affixes":rift_affix_ids(floor, world_id), "actor":world.boss_actor}

func start_rift(world_id: String, floor: int) -> bool:
	if not can_challenge_rift(world_id, floor): return false
	active_rift = {"world":world_id, "floor":floor, "started":Time.get_unix_time_from_system()}
	battle.start_rift_combat(active_rift, rift_profile(world_id, floor))
	return true

func resolve_rift_victory() -> Dictionary:
	if active_rift.is_empty(): return {}
	var world_id := str(active_rift.world)
	var floor := int(active_rift.floor)
	var state: Dictionary = battle.progression.rift_progress[world_id]
	var first: bool = floor not in state.first_clear_claimed
	if first:
		state.first_clear_claimed.append(floor)
		state.highest_clear = maxi(int(state.highest_clear), floor)
	var reward_cfg: Dictionary = config.rift.reward
	var gold := int(reward_cfg.gold_base) + floor * int(reward_cfg.gold_per_floor)
	var material := int(reward_cfg.material_base) + floor / 5
	battle.progression.gold += gold
	var material_id := str(config.rift.worlds[world_id].material)
	battle.progression.materials[material_id] = int(battle.progression.materials.get(material_id, 0)) + material
	battle.combat_stats.resources.materials += material
	if first:
		battle.progression.materials.rift_crystal = int(battle.progression.materials.get("rift_crystal", 0)) + int(reward_cfg.first_clear_crystal)
		battle.combat_stats.resources.materials += int(reward_cfg.first_clear_crystal)
	var quality := "purple" if floor >= 10 else "blue" if floor >= 5 else "green"
	var item: Dictionary = battle.equipment_generator.generate(maxi(1, floor), "%s第%d层" % [config.rift.worlds[world_id].name, floor], quality)
	item["rift_floor"] = floor
	item["rift_world"] = world_id
	if floor >= 5 and item.get("special_effects", []).is_empty():
		var special_ids: Array = battle.special_config.get("effects", {}).keys()
		if not special_ids.is_empty(): item.special_effects = [special_ids[floor % special_ids.size()]]
	if battle.inventory.add_item(item): battle.combat_stats.resources.equipment += 1
	if first and floor % 5 == 0: grant_furniture("rift_beacon", 1)
	battle.progression.record_transaction("秘境结算", "%s第%d层%s" % [config.rift.worlds[world_id].name, floor, "首通" if first else "重复"], gold)
	if bool(state.auto_climb) and floor < main_stage_cap(): state.selected_floor = floor + 1
	else: state.selected_floor = floor
	battle.progression.save_to_disk(); changed.emit()
	var result := {"first":first,"gold":gold,"material":material,"equipment":item,"floor":floor,"world":world_id}
	active_rift.clear()
	return result

func tick(delta: float) -> void:
	if not active_rift.is_empty(): return
	if not active_encounter.is_empty():
		active_encounter.remaining = float(active_encounter.get("remaining", 0.0)) - delta
		if float(active_encounter.remaining) <= 0.0 and str(active_encounter.type) == "wandering_merchant": finish_encounter(false, {})
		return
	event_clock += delta
	var settings: Dictionary = config.get("encounters", {})
	if event_clock < float(settings.get("minimum_interval", 75.0)): return
	if randf() < float(settings.get("chance_per_second", 0.0025)) * delta:
		trigger_weighted_encounter()

func trigger_weighted_encounter() -> String:
	var entries: Dictionary = config.encounters.types
	var total := 0
	for id in entries: total += int(entries[id].weight)
	var roll := randi_range(1, maxi(1, total))
	for id in entries:
		roll -= int(entries[id].weight)
		if roll <= 0:
			trigger_encounter(str(id)); return str(id)
	return ""

func trigger_encounter(event_id: String) -> bool:
	if not active_encounter.is_empty() or not config.encounters.types.has(event_id): return false
	event_clock = 0.0
	battle.progression.encounter_state.serial = int(battle.progression.encounter_state.get("serial", 0)) + 1
	active_encounter = {"type":event_id,"serial":battle.progression.encounter_state.serial,"remaining":float(config.encounters.duration),"completed":false}
	battle.progression.encounter_state.active = active_encounter.duplicate(true)
	var data: Dictionary = config.encounters.types[event_id]
	encounter_notice.emit("奇遇出现：%s" % data.name)
	if event_id == "wandering_merchant":
		build_merchant_stock()
	else:
		var overrides := {"name":data.name,"encounter_type":event_id,"encounter_serial":active_encounter.serial,"boss_id":"encounter_" + event_id}
		var enemy = battle.spawn_unit(str(data.enemy), "enemies", Vector2(870, 250), overrides)
		enemy.enemy_type = "boss" if event_id == "hidden_boss" else "elite"
		var stage := maxi(1, battle.progression.completed_stages.size())
		enemy.monster_level = stage
		enemy.max_hp *= 2.8 if event_id == "hidden_boss" else 1.65
		enemy.hp = enemy.max_hp
		enemy.attack *= 1.8 if event_id == "hidden_boss" else 1.3
	battle.progression.save_to_disk(); changed.emit(); return true

func on_enemy_defeated(unit) -> bool:
	if active_encounter.is_empty() or int(unit.actor_data.get("encounter_serial", -1)) != int(active_encounter.serial): return false
	finish_encounter(true, reward_for_encounter(str(active_encounter.type)))
	return true

func reward_for_encounter(event_id: String) -> Dictionary:
	var stage := maxi(1, battle.progression.completed_stages.size())
	var reward := {"gold":20 + stage * 5,"material":2 + stage / 5}
	battle.progression.gold += int(reward.gold)
	var material_id := "three_kingdoms_token" if stage <= 10 else "pokemon_token" if stage <= 20 else "dragon_blood_crystal" if stage <= 30 else "jianghu_token"
	battle.progression.materials[material_id] = int(battle.progression.materials.get(material_id, 0)) + int(reward.material)
	battle.combat_stats.resources.materials += int(reward.material)
	if event_id in ["rare_elite", "chest_mimic", "hidden_boss"]:
		var quality := "orange" if event_id == "hidden_boss" else "purple" if event_id == "chest_mimic" else "blue"
		var item: Dictionary = battle.equipment_generator.generate(stage, "奇遇·%s" % config.encounters.types[event_id].name, quality)
		if battle.inventory.add_item(item):
			battle.combat_stats.resources.equipment += 1
			reward.equipment = item
	if event_id == "chest_mimic":
		var skill_ids: Array = battle.general_skills_config.keys()
		var book_id := str(skill_ids[randi() % skill_ids.size()]); battle.progression.skill_books[book_id] = int(battle.progression.skill_books.get(book_id, 0)) + 1; reward.skill_book = book_id
		grant_furniture("mimic_chest", 1)
	if event_id == "hidden_boss":
		grant_collectible("rift_core", "裂隙领主核心"); grant_furniture("trophy_stand", 1)
	return reward

func finish_encounter(success: bool, reward: Dictionary) -> void:
	if active_encounter.is_empty(): return
	var id := str(active_encounter.type)
	battle.progression.encounter_counts[id] = int(battle.progression.encounter_counts.get(id, 0)) + 1
	battle.progression.encounter_log.push_front({"id":id,"name":config.encounters.types[id].name,"stage":battle.progression.completed_stages.size(),"time":int(Time.get_unix_time_from_system()),"success":success,"reward":reward})
	if battle.progression.encounter_log.size() > 80: battle.progression.encounter_log.resize(80)
	active_encounter.clear(); battle.progression.encounter_state.active = {}; battle.progression.save_to_disk(); changed.emit()

func build_merchant_stock() -> void:
	var serial := int(active_encounter.serial)
	var rng := RandomNumberGenerator.new(); rng.seed = serial * 7919 + 17
	var stock: Array = [
		{"id":"rift_key","name":"秘境钥匙","type":"special","price":90,"amount":1,"sold":false},
		{"id":"potted_plant","name":"旅行盆栽","type":"furniture","price":140,"amount":1,"sold":false},
		{"id":"rare_wood","name":"稀有木材","type":"material","price":75,"amount":3,"sold":false}
	]
	var skill_ids: Array = battle.general_skills_config.keys()
	var chosen := str(skill_ids[rng.randi_range(0, skill_ids.size() - 1)])
	stock.append({"id":chosen,"name":"技能书·" + str(battle.general_skills_config[chosen].name),"type":"skill_book","price":220,"amount":1,"sold":false})
	battle.progression.encounter_state.merchant_stock = stock
	battle.progression.encounter_state.merchant_expiry = int(Time.get_unix_time_from_system()) + int(config.encounters.duration)

func buy_merchant_item(index: int) -> bool:
	var stock: Array = battle.progression.encounter_state.get("merchant_stock", [])
	if str(active_encounter.get("type", "")) != "wandering_merchant" or index < 0 or index >= stock.size() or bool(stock[index].sold): return false
	var row: Dictionary = stock[index]
	if not battle.progression.spend_gold(int(row.price)): return false
	match str(row.type):
		"special": battle.progression.special_items[row.id] = int(battle.progression.special_items.get(row.id, 0)) + int(row.amount)
		"material": battle.progression.materials[row.id] = int(battle.progression.materials.get(row.id, 0)) + int(row.amount)
		"skill_book": battle.progression.skill_books[row.id] = int(battle.progression.skill_books.get(row.id, 0)) + int(row.amount)
		"furniture": grant_furniture(str(row.id), int(row.amount))
	stock[index].sold = true; battle.progression.encounter_state.merchant_stock = stock; battle.progression.save_to_disk(); changed.emit(); return true

func grant_furniture(id: String, amount: int = 1) -> void:
	battle.progression.camp_inventory[id] = int(battle.progression.camp_inventory.get(id, 0)) + amount

func grant_collectible(id: String, display_name: String) -> void:
	var current: Dictionary = battle.progression.collectibles.get(id, {"name":display_name,"count":0})
	current.count = int(current.count) + 1; battle.progression.collectibles[id] = current

func furniture_available(id: String) -> int:
	var placed := 0
	for row in battle.progression.camp_layout:
		if str(row.get("furniture_id", "")) == id: placed += 1
	return maxi(0, int(battle.progression.camp_inventory.get(id, 0)) - placed)

func place_furniture(id: String, cell: Vector2i) -> bool:
	if furniture_available(id) <= 0 or not config.furniture.has(id): return false
	var size_data: Array = config.furniture[id].get("size", [1,1])
	var rect := Rect2i(cell, Vector2i(int(size_data[0]), int(size_data[1])))
	if cell.x < 0 or cell.y < 0 or rect.end.x > 12 or rect.end.y > 8: return false
	for row in battle.progression.camp_layout:
		var other_size: Array = config.furniture[str(row.furniture_id)].get("size", [1,1])
		if rect.intersects(Rect2i(Vector2i(int(row.x), int(row.y)), Vector2i(int(other_size[0]), int(other_size[1])))): return false
	var placement_id := "%s_%d_%d" % [id, Time.get_ticks_msec(), battle.progression.camp_layout.size()]
	battle.progression.camp_layout.append({"placement_id":placement_id,"furniture_id":id,"x":cell.x,"y":cell.y})
	battle.progression.save_to_disk(); changed.emit(); return true

func move_furniture(placement_id: String, cell: Vector2i) -> bool:
	var removed: Dictionary = {}
	for index in range(battle.progression.camp_layout.size()):
		if str(battle.progression.camp_layout[index].placement_id) == placement_id:
			removed = battle.progression.camp_layout[index]; battle.progression.camp_layout.remove_at(index); break
	if removed.is_empty(): return false
	if place_furniture(str(removed.furniture_id), cell):
		battle.progression.camp_layout.back().placement_id = removed.placement_id
		battle.progression.save_to_disk()
		return true
	battle.progression.camp_layout.append(removed); battle.progression.save_to_disk(); return false

func return_furniture(placement_id: String) -> bool:
	for index in range(battle.progression.camp_layout.size()):
		if str(battle.progression.camp_layout[index].placement_id) == placement_id:
			battle.progression.camp_layout.remove_at(index); battle.progression.save_to_disk(); changed.emit(); return true
	return false

func achievement_ready(id: String) -> bool:
	if not config.achievements.has(id): return false
	var row: Dictionary = config.achievements[id]
	match str(row.condition):
		"party_size": return battle.progression.active_party().size() >= int(row.target)
		"stage": return battle.progression.completed_stages.size() >= int(row.target)
		"encounter_hidden_boss": return int(battle.progression.encounter_counts.get("hidden_boss", 0)) >= int(row.target)
		"encounter_chest_mimic": return int(battle.progression.encounter_counts.get("chest_mimic", 0)) >= int(row.target)
		"rift_floor": return maxi(int(battle.progression.rift_progress.three_kingdoms.highest_clear), int(battle.progression.rift_progress.pokemon.highest_clear)) >= int(row.target)
		"roster_world":
			var count := 0
			for actor_id in battle.progression.roster:
				if str(battle.actors.get(actor_id, {}).get("world", "")) == str(row.world): count += 1
			return count >= int(row.target)
		"furniture_count":
			var total := 0
			for furniture_id in battle.progression.camp_inventory: total += int(battle.progression.camp_inventory[furniture_id])
			return total >= int(row.target)
		"orange_item":
			for item in battle.inventory.items:
				if str(item.get("quality", "")) == "orange": return true
	return false

func claim_achievement(id: String) -> bool:
	if bool(battle.progression.achievements.get(id, {}).get("claimed", false)) or not achievement_ready(id): return false
	var reward: Dictionary = config.achievements[id].reward
	if reward.has("gold"): battle.progression.gold += int(reward.gold)
	if reward.has("furniture"): grant_furniture(str(reward.furniture), 1)
	if reward.has("collectible"): grant_collectible(str(reward.collectible), str(config.achievements[id].name))
	battle.progression.achievements[id] = {"claimed":true,"time":int(Time.get_unix_time_from_system())}
	battle.progression.save_to_disk(); changed.emit(); return true
