class_name ProgressionManager
extends Node

signal changed

const VERSION := "0.6"
const NORMAL_PATH := "user://wanjie_v06_progress.json"
const LEGACY_PATH := "user://wanjie_v05_progress.json"
const V03_LEGACY_PATH := "user://wanjie_v03_progress.json"
const TEST_PATH := "user://wanjie_v06_test_progress.json"
const HERO_IDS := ["zhang_fei", "dian_wei", "zhao_yun", "zhuge_liang", "liu_bei", "lu_bu", "pikachu", "snorlax", "gengar", "mewtwo"]

var save_path := NORMAL_PATH
var materials := {"salvage_dust": 0, "three_kingdoms_token": 0, "pokemon_token": 0}
var recruit_tokens := 1
var gold := 0
var guide_step := 0
var guide_finished := false
var guide_skipped := false
var guide_replay := false
var roster: Array = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
var party: Array = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
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
var migrated_from_legacy := false
var legacy_path := LEGACY_PATH
var v03_legacy_path := V03_LEGACY_PATH
var completed_stages: Array = []
var pokemon_world_unlocked := false
var last_stage_id := "hulao_pass"
var migration_source_version := ""
var level_history: Dictionary = {}

func setup() -> void:
	var args := OS.get_cmdline_user_args()
	var test_mode := "--v03-test" in args or "--v03-persist-write" in args or "--v03-persist-read" in args or "--v031-test" in args or "--v05-test" in args or "--v05-core-test" in args or "--v05-shop-test" in args or "--v05-skill-test" in args or "--v05-system-test" in args or "--v05-persist-write" in args or "--v05-persist-read" in args or "--v06-world-test" in args or "--v06-progression-test" in args or "--v06-character-test" in args
	if test_mode:
		save_path = TEST_PATH
	if "--v03-test" in args or "--v03-persist-write" in args or "--v031-test" in args or "--v05-test" in args or "--v05-core-test" in args or "--v05-shop-test" in args or "--v05-skill-test" in args or "--v05-system-test" in args or "--v05-persist-write" in args or "--v06-world-test" in args or "--v06-progression-test" in args or "--v06-character-test" in args:
		clear_test_save()
	var loaded := load_from_disk()
	if not loaded and save_path == NORMAL_PATH and FileAccess.file_exists(legacy_path):
		loaded = load_legacy_save()
	if not loaded and save_path == NORMAL_PATH and FileAccess.file_exists(v03_legacy_path):
		legacy_path = v03_legacy_path
		loaded = load_legacy_save()
	if not loaded and save_path == NORMAL_PATH and FileAccess.file_exists("user://wanjie_v02_save.json"):
		guide_step = 6
		guide_finished = true
	ensure_growth_layout()
	ensure_world_layout()
	var now := int(Time.get_unix_time_from_system())
	if loaded and last_seen_unix > 0:
		calculate_offline_rewards(now)
	last_seen_unix = now
	if loaded or migrated_from_legacy:
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

func add_recruit_tokens(amount: int) -> void:
	recruit_tokens = maxi(0, recruit_tokens + amount)
	changed.emit()
	save_to_disk()

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

func use_recruit_token(pool: Array, rng: RandomNumberGenerator) -> String:
	if recruit_tokens <= 0:
		return ""
	var available: Array = []
	for id in pool:
		if id not in roster:
			available.append(id)
	if available.is_empty():
		return ""
	var id: String = available[rng.randi_range(0, available.size() - 1)]
	recruit_tokens -= 1
	roster.append(id)
	ensure_growth_layout()
	changed.emit()
	save_to_disk()
	return id

func recruit_token_status(pool: Array) -> String:
	if recruit_tokens <= 0:
		return "招募令不足，可在商店获得。"
	for actor_id in pool:
		if actor_id not in roster:
			return ""
	return "普通招募池角色已全部获得，招募令不会被消耗。"

func exchange_actor(actor_id: String, material_id: String, cost: int) -> bool:
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
		if actor_id not in roster:
			roster.append(actor_id)
		ensure_growth_layout()
		changed.emit()
		save_to_disk()
	return first

func set_party_member(index: int, actor_id: String) -> bool:
	if index < 0 or index >= 4 or actor_id not in roster:
		return false
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

func add_actor_experience(actor_id: String, amount: int, autosave: bool = true, source: String = "combat") -> bool:
	if actor_id not in HERO_IDS or amount <= 0:
		return false
	ensure_growth_layout()
	actor_experience[actor_id] = int(actor_experience[actor_id]) + amount
	var leveled := false
	while int(actor_levels[actor_id]) < 60:
		var needed := experience_to_next(int(actor_levels[actor_id]))
		if int(actor_experience[actor_id]) < needed:
			break
		actor_experience[actor_id] = int(actor_experience[actor_id]) - needed
		actor_levels[actor_id] = int(actor_levels[actor_id]) + 1
		level_history[actor_id].push_front({"level": int(actor_levels[actor_id]), "time": int(Time.get_unix_time_from_system()), "source": source})
		if level_history[actor_id].size() > 20:
			level_history[actor_id].resize(20)
		leveled = true
	if autosave:
		changed.emit()
		save_to_disk()
	return leveled

func experience_to_next(level: int) -> int:
	return 35 + level * level * 8

func experience_for_kill(monster_level: int, enemy_type: String, hero_level: int) -> int:
	var base := 5.0 + maxf(1.0, monster_level) * 2.0
	var type_multiplier := 1.0
	match enemy_type:
		"elite": type_multiplier = 2.5
		"boss": type_multiplier = 8.0
	var level_gap := hero_level - monster_level
	var farm_multiplier := 1.0
	if level_gap > 3:
		farm_multiplier = maxf(0.15, 1.0 - (level_gap - 3) * 0.12)
	return maxi(1, roundi(base * type_multiplier * farm_multiplier))

func actor_level(actor_id: String) -> int:
	return maxi(1, int(actor_levels.get(actor_id, 1)))

func party_average_level() -> float:
	if party.is_empty():
		return 1.0
	var total := 0.0
	for actor_id in party:
		total += actor_level(actor_id)
	return total / party.size()

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
	var payload := {"version": VERSION, "materials": materials, "recruit_tokens": recruit_tokens, "gold": gold, "roster": roster, "party": party, "boss_first_clear": boss_first_clear, "strategy_presets": strategy_presets, "active_strategy": active_strategy, "guide_step": guide_step, "guide_finished": guide_finished, "guide_skipped": guide_skipped, "guide_replay": guide_replay, "actor_levels": actor_levels, "actor_experience": actor_experience, "skill_levels": skill_levels, "level_history": level_history, "transaction_log": transaction_log, "pending_offline": pending_offline, "last_seen_unix": last_seen_unix, "migrated_from_legacy": migrated_from_legacy, "migration_source_version": migration_source_version, "completed_stages": completed_stages, "pokemon_world_unlocked": pokemon_world_unlocked, "last_stage_id": last_stage_id}
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

func load_legacy_save() -> bool:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(legacy_path))
	if not apply_payload(parsed):
		return false
	migrated_from_legacy = true
	migration_source_version = str(parsed.get("version", "unknown")) if typeof(parsed) == TYPE_DICTIONARY else "unknown"
	# V0.5 only had six level-gated maps and no clear record. Never infer that
	# the new Three Kingdoms finale was completed from old map/Boss access.
	completed_stages = []
	pokemon_world_unlocked = false
	last_stage_id = "hulao_pass"
	last_seen_unix = int(Time.get_unix_time_from_system())
	return true

func apply_payload(parsed) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload_version := str(parsed.get("version", ""))
	materials.merge(parsed.get("materials", {}), true)
	recruit_tokens = maxi(0, int(parsed.get("recruit_tokens", recruit_tokens)))
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
	transaction_log = parsed.get("transaction_log", [])
	pending_offline.merge(parsed.get("pending_offline", {}), true)
	last_seen_unix = int(parsed.get("last_seen_unix", 0))
	migrated_from_legacy = bool(parsed.get("migrated_from_legacy", false))
	migration_source_version = str(parsed.get("migration_source_version", ""))
	if payload_version == VERSION:
		completed_stages = parsed.get("completed_stages", [])
		pokemon_world_unlocked = bool(parsed.get("pokemon_world_unlocked", false))
		last_stage_id = str(parsed.get("last_stage_id", "hulao_pass"))
	else:
		completed_stages = []
		pokemon_world_unlocked = false
		last_stage_id = "hulao_pass"
	if roster.is_empty():
		roster = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
	while party.size() < 4:
		party.append(roster[party.size() % roster.size()])
	if party.size() > 4:
		party.resize(4)
	ensure_growth_layout()
	ensure_world_layout()
	return true
