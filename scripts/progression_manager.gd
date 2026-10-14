class_name ProgressionManager
extends Node

signal changed

const VERSION := "0.6.1"
const NORMAL_PATH := "user://wanjie_v061_progress.json"
const TEST_PATH := "user://wanjie_v061_test_progress.json"
const HERO_IDS := ["zhang_fei", "dian_wei", "zhao_yun", "zhuge_liang", "liu_bei", "lu_bu", "pikachu", "snorlax", "gengar", "mewtwo"]

var save_path := NORMAL_PATH
var materials := {"salvage_dust": 0, "three_kingdoms_token": 150, "pokemon_token": 0}
var gold := 0
var guide_step := 0
var guide_finished := false
var guide_skipped := false
var guide_replay := false
var roster: Array = ["liu_bei"]
var party: Array = ["liu_bei", "", "", ""]
var boss_first_clear := {"lu_bu": false, "mewtwo": false}
var strategy_presets := {
	"稳健": {"self_hp": 0.45, "ally_hp": 0.65, "enemy_count": 1},
	"猛攻": {"self_hp": 0.25, "ally_hp": 0.40, "enemy_count": 2}
}
var active_strategy := "稳健"
var actor_levels: Dictionary = {}
var actor_experience: Dictionary = {}
var skill_levels: Dictionary = {}
var transaction_log: Array = []
var pending_offline := {"seconds": 0, "gold": 0, "three_kingdoms_token": 0, "pokemon_token": 0}
var last_seen_unix := 0
var completed_stages: Array = []
var pokemon_world_unlocked := false
var last_stage_id := "hulao_pass"
var level_history: Dictionary = {}
var learned_general_skills: Dictionary = {}
var equipped_general_skills: Dictionary = {}
var general_skill_levels: Dictionary = {}
var skill_priorities: Dictionary = {}
var skill_books: Dictionary = {}
var auto_push := true
var progression_config: Dictionary = {}

func setup() -> void:
	progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	if typeof(progression_config) != TYPE_DICTIONARY: progression_config = {}
	var args := OS.get_cmdline_user_args()
	var test_mode := false
	for value in args:
		if str(value).begins_with("--v061-"):
			test_mode = true
			break
	if test_mode:
		save_path = TEST_PATH
	if test_mode and "--v061-persist-read" not in args:
		clear_test_save()
	var loaded := load_from_disk()
	ensure_growth_layout()
	ensure_world_layout()
	var now := int(Time.get_unix_time_from_system())
	if loaded and last_seen_unix > 0:
		calculate_offline_rewards(now)
	last_seen_unix = now
	if loaded:
		save_to_disk()

func clear_test_save() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func ensure_growth_layout() -> void:
	for actor_id in HERO_IDS:
		actor_levels[actor_id] = maxi(1, int(actor_levels.get(actor_id, 1)))
		actor_experience[actor_id] = maxi(0, int(actor_experience.get(actor_id, 0)))
		if not skill_levels.has(actor_id) or typeof(skill_levels.get(actor_id, {})) != TYPE_DICTIONARY:
			skill_levels[actor_id] = {}
		skill_levels[actor_id]["active"] = clampi(int(skill_levels[actor_id].get("active", 1)), 1, 10)
		skill_levels[actor_id]["passive"] = clampi(int(skill_levels[actor_id].get("passive", 1)), 1, 10)
		if not level_history.has(actor_id) or typeof(level_history.get(actor_id, [])) != TYPE_ARRAY:
			level_history[actor_id] = []
		if not learned_general_skills.has(actor_id) or typeof(learned_general_skills.get(actor_id, [])) != TYPE_ARRAY:
			learned_general_skills[actor_id] = []
		if not equipped_general_skills.has(actor_id) or typeof(equipped_general_skills.get(actor_id, {})) != TYPE_DICTIONARY:
			equipped_general_skills[actor_id] = {"active": [], "passive": []}
		for category in ["active", "passive"]:
			var slots = equipped_general_skills[actor_id].get(category, [])
			if typeof(slots) == TYPE_STRING:
				slots = [slots] if not str(slots).is_empty() else []
			if typeof(slots) != TYPE_ARRAY: slots = []
			var limit := 3 if category == "active" else 4
			while slots.size() < limit: slots.append("")
			if slots.size() > limit: slots.resize(limit)
			equipped_general_skills[actor_id][category] = slots
		if not general_skill_levels.has(actor_id) or typeof(general_skill_levels.get(actor_id, {})) != TYPE_DICTIONARY:
			general_skill_levels[actor_id] = {}
		if not skill_priorities.has(actor_id) or typeof(skill_priorities.get(actor_id, [])) != TYPE_ARRAY:
			skill_priorities[actor_id] = ["exclusive", "general"]

func ensure_world_layout() -> void:
	var sanitized: Array = []
	for value in completed_stages:
		var stage := int(value)
		if stage >= 1 and stage <= 20 and stage not in sanitized:
			sanitized.append(stage)
	sanitized.sort()
	# A stage is valid only when every earlier main stage was completed. This
	# prevents hand-edited/old entry points from skipping the campaign lock.
	var contiguous: Array = []
	for stage in range(1, 21):
		if stage in sanitized:
			contiguous.append(stage)
		else:
			break
	completed_stages = contiguous
	pokemon_world_unlocked = 10 in completed_stages
	if last_stage_id.is_empty():
		last_stage_id = "hulao_pass"

func highest_unlocked_stage() -> int:
	ensure_world_layout()
	return mini(20, completed_stages.size() + 1)

func is_stage_complete(stage: int) -> bool:
	return stage in completed_stages

func can_enter_stage(stage: int) -> bool:
	ensure_world_layout()
	if stage < 1 or stage > 20:
		return false
	if stage >= 11 and not pokemon_world_unlocked:
		return false
	return stage <= highest_unlocked_stage()

func complete_stage(stage: int) -> bool:
	ensure_world_layout()
	if stage != highest_unlocked_stage() or not can_enter_stage(stage):
		return false
	completed_stages.append(stage)
	ensure_world_layout()
	record_transaction("主线通关", "全局第%d关" % stage, 0)
	changed.emit()
	save_to_disk()
	return true

func set_last_stage(map_id: String, stage: int) -> bool:
	if not can_enter_stage(stage):
		return false
	last_stage_id = map_id
	changed.emit()
	save_to_disk()
	return true

func add_material(id: String, amount: int) -> void:
	materials[id] = maxi(0, int(materials.get(id, 0)) + amount)
	changed.emit()
	save_to_disk()

func spend_material(id: String, amount: int) -> bool:
	if amount < 0 or int(materials.get(id, 0)) < amount:
		return false
	materials[id] = int(materials.get(id, 0)) - amount
	changed.emit()
	save_to_disk()
	return true

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	changed.emit()
	save_to_disk()

func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	changed.emit()
	save_to_disk()
	return true

func set_guide_step(value: int) -> void:
	guide_step = clampi(value, 0, 6)
	guide_finished = guide_step >= 6
	if guide_finished:
		guide_replay = false
	guide_skipped = false
	changed.emit()
	save_to_disk()

func skip_guide() -> void:
	guide_finished = true
	guide_skipped = true
	guide_replay = false
	changed.emit()
	save_to_disk()

func restart_guide() -> void:
	guide_step = 0
	guide_finished = false
	guide_skipped = false
	guide_replay = true
	changed.emit()
	save_to_disk()

func exchange_actor(actor_id: String, material_id: String, cost: int) -> bool:
	if actor_id in ["lu_bu", "mewtwo"] and not bool(boss_first_clear.get("lu_bu" if actor_id == "lu_bu" else "mewtwo", false)):
		return false
	if actor_id in roster or not spend_material(material_id, cost):
		return false
	roster.append(actor_id)
	ensure_growth_layout()
	changed.emit()
	save_to_disk()
	return true

func unlock_boss_actor(boss_id: String, actor_id: String) -> bool:
	var first := not bool(boss_first_clear.get(boss_id, false))
	if first:
		boss_first_clear[boss_id] = true
		ensure_growth_layout()
		changed.emit()
		save_to_disk()
	return first

func set_party_member(index: int, actor_id: String) -> bool:
	if index < 0 or index >= 4 or (not actor_id.is_empty() and actor_id not in roster):
		return false
	if actor_id.is_empty():
		party[index] = ""
		changed.emit()
		save_to_disk()
		return true
	var existing := party.find(actor_id)
	if existing >= 0 and existing != index:
		var old: String = party[index]
		party[index] = actor_id
		party[existing] = old
	else:
		party[index] = actor_id
	changed.emit()
	save_to_disk()
	return true

func active_party() -> Array:
	var result: Array = []
	for actor_id in party:
		if not str(actor_id).is_empty(): result.append(actor_id)
	return result

func add_actor_experience(actor_id: String, amount: int, autosave: bool = true, source: String = "combat") -> bool:
	if actor_id not in HERO_IDS or amount <= 0:
		return false
	ensure_growth_layout()
	var cap := actor_level_cap()
	var current_level := int(actor_levels[actor_id])
	if current_level >= cap:
		var storage_limit := floori(experience_to_next(current_level) * float(progression_config.get("cap_storage_ratio", 0.25)))
		actor_experience[actor_id] = mini(storage_limit, int(actor_experience[actor_id]) + amount)
		if autosave: changed.emit(); save_to_disk()
		return false
	actor_experience[actor_id] = int(actor_experience[actor_id]) + amount
	var leveled := false
	var maximum := int(progression_config.get("max_actor_level", 60))
	while int(actor_levels[actor_id]) < mini(maximum, cap):
		var needed := experience_to_next(int(actor_levels[actor_id]))
		if int(actor_experience[actor_id]) < needed:
			break
		actor_experience[actor_id] = int(actor_experience[actor_id]) - needed
		actor_levels[actor_id] = int(actor_levels[actor_id]) + 1
		level_history[actor_id].push_front({"level": int(actor_levels[actor_id]), "time": int(Time.get_unix_time_from_system()), "source": source})
		if level_history[actor_id].size() > 20:
			level_history[actor_id].resize(20)
		leveled = true
	if int(actor_levels[actor_id]) >= cap:
		actor_experience[actor_id] = mini(int(actor_experience[actor_id]), floori(experience_to_next(int(actor_levels[actor_id])) * float(progression_config.get("cap_storage_ratio", 0.25))))
	if autosave:
		changed.emit()
		save_to_disk()
	return leveled

func experience_to_next(level: int) -> int:
	var curve: Dictionary = progression_config.get("experience_curve", {})
	return int(curve.get("base", 180)) + level * int(curve.get("linear", 90)) + level * level * int(curve.get("quadratic", 25))

func actor_level_cap() -> int:
	return clampi(maxi(1, completed_stages.size()), 1, int(progression_config.get("max_actor_level", 60)))

func experience_for_kill(monster_level: int, enemy_type: String, hero_level: int) -> int:
	var reward: Dictionary = progression_config.get("kill_experience", {})
	var base := float(reward.get("base", 3.0)) + maxf(1.0, monster_level) * float(reward.get("per_monster_level", 1.2))
	var type_multiplier := 1.0
	match enemy_type:
		"elite": type_multiplier = float(reward.get("elite_multiplier", 3.0))
		"boss": type_multiplier = float(reward.get("boss_multiplier", 10.0))
	var level_gap := hero_level - monster_level
	var farm_multiplier := 1.0
	var farm: Dictionary = progression_config.get("low_stage_farm", {})
	var free_gap := int(farm.get("free_level_gap", 2))
	if level_gap > free_gap:
		farm_multiplier = maxf(float(farm.get("minimum_multiplier", 0.08)), 1.0 - (level_gap - free_gap) * float(farm.get("penalty_per_level", 0.16)))
	return maxi(1, roundi(base * type_multiplier * farm_multiplier))

func actor_level(actor_id: String) -> int:
	return maxi(1, int(actor_levels.get(actor_id, 1)))

func party_average_level() -> float:
	var active := active_party()
	if active.is_empty():
		return 1.0
	var total := 0.0
	for actor_id in active:
		total += actor_level(actor_id)
	return total / active.size()

func skill_level(actor_id: String, kind: String) -> int:
	ensure_growth_layout()
	return int(skill_levels.get(actor_id, {}).get(kind, 1))

func skill_upgrade_cost(actor_id: String, kind: String) -> Dictionary:
	var level := skill_level(actor_id, kind)
	return {"gold": 30 + level * 25, "salvage_dust": 2 + level * 2}

func upgrade_skill(actor_id: String, kind: String) -> bool:
	if actor_id not in roster or kind not in ["active", "passive"]:
		return false
	var level := skill_level(actor_id, kind)
	if level >= 10:
		return false
	var cost := skill_upgrade_cost(actor_id, kind)
	if gold < int(cost.gold) or int(materials.get("salvage_dust", 0)) < int(cost.salvage_dust):
		return false
	gold -= int(cost.gold)
	materials["salvage_dust"] = int(materials.get("salvage_dust", 0)) - int(cost.salvage_dust)
	skill_levels[actor_id][kind] = level + 1
	record_transaction("技能升级", "%s:%s Lv.%d" % [actor_id, kind, level + 1], -int(cost.gold))
	changed.emit()
	save_to_disk()
	return true

func grant_skill_book(skill_id: String, amount: int = 1, source: String = "drop") -> bool:
	if skill_id.is_empty() or amount <= 0:
		return false
	skill_books[skill_id] = int(skill_books.get(skill_id, 0)) + amount
	record_transaction("获得技能书", "%s ×%d（%s）" % [skill_id, amount, source], 0)
	changed.emit()
	save_to_disk()
	return true

func skill_book_count(skill_id: String) -> int:
	return maxi(0, int(skill_books.get(skill_id, 0)))

func learn_general_skill(actor_id: String, skill_id: String) -> bool:
	if actor_id not in roster or skill_id.is_empty() or skill_id in learned_general_skills.get(actor_id, []):
		return false
	if skill_book_count(skill_id) < 1:
		return false
	skill_books[skill_id] = skill_book_count(skill_id) - 1
	learned_general_skills[actor_id].append(skill_id)
	general_skill_levels[actor_id][skill_id] = 1
	record_transaction("学习通用技能", "%s:%s（消耗技能书）" % [actor_id, skill_id], 0)
	changed.emit()
	save_to_disk()
	return true

func equip_general_skill(actor_id: String, skill_id: String, category: String, slot_index: int = -1) -> bool:
	if actor_id not in roster or category not in ["active", "passive"]:
		return false
	if not skill_id.is_empty() and skill_id not in learned_general_skills.get(actor_id, []):
		return false
	var slots: Array = equipped_general_skills[actor_id][category]
	var limit := 3 if category == "active" else 4
	if slot_index < 0:
		slot_index = slots.find(skill_id)
		if slot_index < 0: slot_index = slots.find("")
		if slot_index < 0: slot_index = 0
	if slot_index < 0 or slot_index >= limit:
		return false
	var existing := slots.find(skill_id)
	if existing >= 0 and existing != slot_index: slots[existing] = ""
	slots[slot_index] = skill_id
	equipped_general_skills[actor_id][category] = slots
	changed.emit()
	save_to_disk()
	return true

func unequip_general_skill(actor_id: String, category: String, slot_index: int) -> bool:
	return equip_general_skill(actor_id, "", category, slot_index)

func equipped_skill_ids(actor_id: String, category: String) -> Array:
	ensure_growth_layout()
	var result: Array = []
	for skill_id in equipped_general_skills[actor_id].get(category, []):
		if not str(skill_id).is_empty(): result.append(str(skill_id))
	return result

func general_skill_level(actor_id: String, skill_id: String) -> int:
	return maxi(1, int(general_skill_levels.get(actor_id, {}).get(skill_id, 1)))

func upgrade_general_skill(actor_id: String, skill_id: String) -> bool:
	if skill_id not in learned_general_skills.get(actor_id, []):
		return false
	var level := general_skill_level(actor_id, skill_id)
	if level >= 10:
		return false
	var cost_gold := 35 + level * 30
	if gold < cost_gold or skill_book_count(skill_id) < 1:
		return false
	gold -= cost_gold
	skill_books[skill_id] = skill_book_count(skill_id) - 1
	general_skill_levels[actor_id][skill_id] = level + 1
	record_transaction("通用技能升级", "%s:%s Lv.%d（技能书×1）" % [actor_id, skill_id, level + 1], -cost_gold)
	changed.emit()
	save_to_disk()
	return true

func toggle_skill_priority(actor_id: String) -> void:
	if skill_priorities.get(actor_id, ["exclusive", "general"])[0] == "exclusive":
		skill_priorities[actor_id] = ["general", "exclusive"]
	else:
		skill_priorities[actor_id] = ["exclusive", "general"]
	changed.emit()
	save_to_disk()

func record_transaction(action: String, detail: String, gold_delta: int) -> void:
	transaction_log.push_front({"time": int(Time.get_unix_time_from_system()), "action": action, "detail": detail, "gold": gold_delta})
	if transaction_log.size() > 30:
		transaction_log.resize(30)

func calculate_offline_rewards(now_unix: int) -> Dictionary:
	if last_seen_unix <= 0 or now_unix <= last_seen_unix:
		return pending_offline
	var seconds := mini(now_unix - last_seen_unix, 8 * 60 * 60)
	if seconds < 60:
		return pending_offline
	pending_offline.seconds = maxi(int(pending_offline.get("seconds", 0)), seconds)
	pending_offline.gold = maxi(int(pending_offline.get("gold", 0)), seconds / 30)
	pending_offline.three_kingdoms_token = maxi(int(pending_offline.get("three_kingdoms_token", 0)), seconds / 300)
	pending_offline.pokemon_token = maxi(int(pending_offline.get("pokemon_token", 0)), seconds / 300)
	return pending_offline

func claim_offline_rewards() -> Dictionary:
	var reward: Dictionary = pending_offline.duplicate(true)
	if int(reward.get("seconds", 0)) <= 0:
		return {}
	gold += int(reward.get("gold", 0))
	materials["three_kingdoms_token"] = int(materials.get("three_kingdoms_token", 0)) + int(reward.get("three_kingdoms_token", 0))
	materials["pokemon_token"] = int(materials.get("pokemon_token", 0)) + int(reward.get("pokemon_token", 0))
	pending_offline = {"seconds": 0, "gold": 0, "three_kingdoms_token": 0, "pokemon_token": 0}
	last_seen_unix = int(Time.get_unix_time_from_system())
	record_transaction("离线收益", "%d秒" % int(reward.seconds), int(reward.gold))
	changed.emit()
	save_to_disk()
	return reward

func save_to_disk() -> bool:
	last_seen_unix = maxi(last_seen_unix, int(Time.get_unix_time_from_system()))
	var payload := {"version": VERSION, "materials": materials, "gold": gold, "roster": roster, "party": party, "boss_first_clear": boss_first_clear, "strategy_presets": strategy_presets, "active_strategy": active_strategy, "guide_step": guide_step, "guide_finished": guide_finished, "guide_skipped": guide_skipped, "guide_replay": guide_replay, "actor_levels": actor_levels, "actor_experience": actor_experience, "skill_levels": skill_levels, "level_history": level_history, "learned_general_skills": learned_general_skills, "equipped_general_skills": equipped_general_skills, "general_skill_levels": general_skill_levels, "skill_priorities": skill_priorities, "skill_books": skill_books, "auto_push": auto_push, "transaction_log": transaction_log, "pending_offline": pending_offline, "last_seen_unix": last_seen_unix, "completed_stages": completed_stages, "pokemon_world_unlocked": pokemon_world_unlocked, "last_stage_id": last_stage_id}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入进度存档: " + save_path)
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return true

func load_from_disk() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	return apply_payload(JSON.parse_string(FileAccess.get_file_as_string(save_path)))

func apply_payload(parsed) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload_version := str(parsed.get("version", ""))
	if payload_version != VERSION:
		return false
	materials.merge(parsed.get("materials", {}), true)
	gold = maxi(0, int(parsed.get("gold", 0)))
	guide_step = clampi(int(parsed.get("guide_step", 6)), 0, 6)
	guide_finished = bool(parsed.get("guide_finished", true))
	guide_skipped = bool(parsed.get("guide_skipped", false))
	guide_replay = bool(parsed.get("guide_replay", false))
	roster = parsed.get("roster", roster)
	party = parsed.get("party", party)
	boss_first_clear.merge(parsed.get("boss_first_clear", {}), true)
	strategy_presets.merge(parsed.get("strategy_presets", {}), true)
	active_strategy = parsed.get("active_strategy", active_strategy)
	actor_levels = parsed.get("actor_levels", {})
	actor_experience = parsed.get("actor_experience", {})
	skill_levels = parsed.get("skill_levels", {})
	level_history = parsed.get("level_history", {})
	learned_general_skills = parsed.get("learned_general_skills", {})
	equipped_general_skills = parsed.get("equipped_general_skills", {})
	general_skill_levels = parsed.get("general_skill_levels", {})
	skill_priorities = parsed.get("skill_priorities", {})
	skill_books = parsed.get("skill_books", {})
	auto_push = bool(parsed.get("auto_push", true))
	transaction_log = parsed.get("transaction_log", [])
	pending_offline.merge(parsed.get("pending_offline", {}), true)
	last_seen_unix = int(parsed.get("last_seen_unix", 0))
	completed_stages = parsed.get("completed_stages", [])
	pokemon_world_unlocked = bool(parsed.get("pokemon_world_unlocked", false))
	last_stage_id = str(parsed.get("last_stage_id", "hulao_pass"))
	if roster.is_empty():
		roster = ["liu_bei"]
	while party.size() < 4:
		party.append("")
	if party.size() > 4:
		party.resize(4)
	ensure_growth_layout()
	ensure_world_layout()
	return true
