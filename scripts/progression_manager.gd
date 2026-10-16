class_name ProgressionManager
extends Node

signal changed

const VERSION := "1.0"
const NORMAL_PATH := "user://wanjie_v10_progress.json"
const LEGACY_V09_PATH := "user://wanjie_v09_progress.json"
const LEGACY_V08_PATH := "user://wanjie_v08_progress.json"
const LEGACY_PATH := "user://wanjie_v07_progress.json"
const LEGACY_V061_PATH := "user://wanjie_v061_progress.json"
const MIGRATION_BACKUP_PATH := "user://wanjie_v09_progress.pre_v10_backup.json"
const TEAM_MIGRATION_BACKUP_PATH := "user://wanjie_v10_progress.pre_team_backup.json"
const TEST_PATH := "user://wanjie_v10_test_progress.json"
const RESET_MARKER_PATH := "user://wanjie_reset_marker.json"
const DIFFICULTY_CONFIG_VERSION := 2
const LEGACY_DIFFICULTY_BASE := 2.5
const MAIN_STAGE_LIMIT := 100
const TEAM_PROGRESSION_VERSION := 1
const HERO_IDS := ["zhang_fei", "dian_wei", "zhao_yun", "zhuge_liang", "liu_bei", "lu_bu", "guan_yu", "huang_zhong", "diao_chan", "zhou_yu", "pikachu", "snorlax", "gengar", "mewtwo", "bulbasaur", "charmander", "squirtle", "lucario", "gardevoir", "dragonite", "chen_motong", "chu_zihang", "yabuki_sakura", "lu_mingfei", "lu_mingze", "caesar", "eri_uesugi", "minamoto_chisei", "minamoto_chime", "zero", "blood_river", "iron_guard", "broken_dream", "divine_harmony", "plain_question", "nine_spirits", "varian_wrynn", "anduin_wrynn", "thrall", "arthas_menethil", "illidan_stormrage", "jaina_proudmoore", "guo_jing", "huang_rong", "yang_guo", "xiaolongnu", "zhang_wuji", "zhou_zhiruo", "qiao_feng", "duan_yu", "linghu_chong", "ren_yingying", "qin_gai_nie", "qin_wei_zhuang", "qin_jing_tianming", "qin_xiang_shaoyu", "qin_gao_jianli", "qin_xue_nv", "qin_duanmu_rong", "qin_shaosiming", "qin_xiaomeng", "qin_zhang_liang", "naruto_uzumaki", "naruto_sasuke", "naruto_sakura", "naruto_kakashi", "naruto_itachi", "naruto_shikamaru", "naruto_hinata", "naruto_gaara", "naruto_jiraiya", "naruto_tsunade", "hy_long_ying", "hy_wu_zhao", "hy_kou_zhong", "hy_xu_ziling", "hy_wan_wan", "hy_fa_ming", "hy_yan_fei", "hy_sun_en", "hy_ling_donglai", "hy_lang_fanyun"]
const FENGYUN_HERO_IDS := ["fy_nie_feng", "fy_bu_jingyun", "fy_wuming", "fy_sword_saint", "fy_wu_wudi", "fy_xiao_wu", "fy_duan_lang", "fy_di_er_meng", "fy_jian_chen", "fy_di_shitian"]
const ALL_HERO_IDS := HERO_IDS + FENGYUN_HERO_IDS

var save_path := NORMAL_PATH
var materials := {"salvage_dust": 0, "three_kingdoms_token": 150, "pokemon_token": 0, "dragon_blood_crystal": 0, "jianghu_token": 0, "azeroth_token": 0, "wuxia_token": 0, "qin_moon_token": 0, "ninja_scroll": 0, "huangyi_token": 0, "fengyun_token": 0}
var gold := 0
var guide_step := 0
var guide_finished := false
var guide_skipped := false
var guide_replay := false
var roster: Array = ["liu_bei"]
var party: Array = ["liu_bei", "", "", ""]
var boss_first_clear := {"lu_bu": false, "mewtwo": false, "nidhogg": false, "liuxingwen": false, "lich_king": false, "dongfang_bubai": false, "donghuang_taiyi": false, "madara": false, "pang_ban": false, "di_shitian": false}
var strategy_presets := {
	"稳健": {"self_hp": 0.45, "ally_hp": 0.65, "enemy_count": 1},
	"猛攻": {"self_hp": 0.25, "ally_hp": 0.40, "enemy_count": 2}
}
var active_strategy := "稳健"
# Shared progression is authoritative. These dictionaries are synchronized
# compatibility mirrors for older validation/debug callers and are never saved.
var team_level := 1
var team_exp := 0
var team_progression_version := TEAM_PROGRESSION_VERSION
var team_level_history: Array = []
var actor_levels: Dictionary = {}
var actor_experience: Dictionary = {}
var skill_levels: Dictionary = {}
var transaction_log: Array = []
var pending_offline := {"seconds": 0, "gold": 0, "three_kingdoms_token": 0, "pokemon_token": 0, "dragon_blood_crystal":0, "jianghu_token":0, "azeroth_token":0, "wuxia_token":0, "qin_moon_token":0, "ninja_scroll":0, "huangyi_token":0, "fengyun_token":0}
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
var special_items: Dictionary = {"recruit_ticket": 0, "camp_coupon": 0, "rift_key": 0}
var collectibles: Dictionary = {}
var rift_progress: Dictionary = {
	"three_kingdoms": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
	"pokemon": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
	"dragon": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
	"nsh": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"wow": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"jinyong": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"qin": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"naruto": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"huangyi": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	,"fengyun": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
}
var encounter_state: Dictionary = {"last_trigger_unix": 0, "active": {}, "merchant_stock": [], "merchant_expiry": 0, "serial": 0}
var encounter_log: Array = []
var encounter_counts: Dictionary = {}
var camp_inventory: Dictionary = {"camp_flag": 1, "campfire": 1, "tent": 1, "bench": 1}
var camp_layout: Array = []
var achievements: Dictionary = {}
var auto_push := true
var combat_difficulty := 1.0
var difficulty_config_version := DIFFICULTY_CONFIG_VERSION
var auto_equipment_settings: Dictionary = default_auto_equipment_settings()
var progression_config: Dictionary = {}

static func default_auto_equipment_settings() -> Dictionary:
	return {
		"sell_enabled": false,
		"sell_max_quality": "white",
		"dismantle_enabled": false,
		"dismantle_max_quality": "white",
		"priority": "dismantle",
		"keep_special_effects": true
	}

func set_auto_equipment_setting(key: String, value, autosave: bool = true) -> bool:
	if key not in default_auto_equipment_settings():
		return false
	if key in ["sell_max_quality", "dismantle_max_quality"] and str(value) not in ["white", "green", "blue", "purple", "orange"]:
		return false
	if key == "priority" and str(value) not in ["dismantle", "sell"]:
		return false
	auto_equipment_settings[key] = value
	changed.emit()
	if autosave:
		save_to_disk()
	return true

func setup() -> void:
	progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	if typeof(progression_config) != TYPE_DICTIONARY: progression_config = {}
	var args := OS.get_cmdline_user_args()
	var test_mode := false
	for value in args:
		if str(value).begins_with("--v061-") or str(value).begins_with("--v07-") or str(value).begins_with("--v08-") or str(value).begins_with("--v081-") or str(value).begins_with("--v09-") or str(value).begins_with("--v10-"):
			test_mode = true
			break
	if test_mode:
		save_path = TEST_PATH
	if test_mode and "--v061-persist-read" not in args and "--v07-persist-read" not in args and "--v08-persist-read" not in args and "--v081-reset-read" not in args:
		clear_test_save()
	var loaded := load_from_disk()
	ensure_growth_layout()
	ensure_world_layout()
	ensure_adventure_layout()
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
	for actor_id in ALL_HERO_IDS:
		actor_levels[actor_id] = team_level
		actor_experience[actor_id] = team_exp
		if not skill_levels.has(actor_id) or typeof(skill_levels.get(actor_id, {})) != TYPE_DICTIONARY:
			skill_levels[actor_id] = {}
		skill_levels[actor_id]["active"] = clampi(int(skill_levels[actor_id].get("active", 1)), 1, 10)
		skill_levels[actor_id]["passive"] = clampi(int(skill_levels[actor_id].get("passive", 1)), 1, 10)
		level_history[actor_id] = team_level_history.duplicate(true)
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
		if stage >= 1 and stage <= MAIN_STAGE_LIMIT and stage not in sanitized:
			sanitized.append(stage)
	sanitized.sort()
	# A stage is valid only when every earlier main stage was completed. This
	# prevents hand-edited/old entry points from skipping the campaign lock.
	var contiguous: Array = []
	for stage in range(1, MAIN_STAGE_LIMIT + 1):
		if stage in sanitized:
			contiguous.append(stage)
		else:
			break
	completed_stages = contiguous
	pokemon_world_unlocked = 10 in completed_stages
	if last_stage_id.is_empty():
		last_stage_id = "hulao_pass"

func ensure_adventure_layout() -> void:
	var defaults := {
		"three_kingdoms":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]},
		"pokemon":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]},
		"dragon":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]},
		"nsh":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"wow":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"jinyong":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"qin":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"naruto":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"huangyi":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
		,"fengyun":{"highest_clear":0,"selected_floor":1,"auto_climb":true,"first_clear_claimed":[]}
	}
	for world_id in defaults:
		if typeof(rift_progress.get(world_id, {})) != TYPE_DICTIONARY: rift_progress[world_id] = {}
		for key in defaults[world_id]:
			if not rift_progress[world_id].has(key): rift_progress[world_id][key] = defaults[world_id][key]
		rift_progress[world_id].highest_clear = maxi(0, int(rift_progress[world_id].highest_clear))
		rift_progress[world_id].selected_floor = maxi(1, int(rift_progress[world_id].selected_floor))
		if not rift_progress[world_id].has("repeat_floor"): rift_progress[world_id].repeat_floor = false
		rift_progress[world_id].repeat_floor = bool(rift_progress[world_id].repeat_floor)
		rift_progress[world_id].auto_climb = bool(rift_progress[world_id].get("auto_climb", true))
		if bool(rift_progress[world_id].repeat_floor): rift_progress[world_id].auto_climb = false
		if typeof(rift_progress[world_id].first_clear_claimed) != TYPE_ARRAY: rift_progress[world_id].first_clear_claimed = []
	if typeof(encounter_log) != TYPE_ARRAY: encounter_log = []
	if typeof(camp_layout) != TYPE_ARRAY: camp_layout = []
	for id in special_items: special_items[id] = maxi(0, int(special_items[id]))
	for id in camp_inventory: camp_inventory[id] = maxi(0, int(camp_inventory[id]))

func set_rift_mode(world_id: String, mode: String) -> bool:
	ensure_adventure_layout()
	if not rift_progress.has(world_id) or mode not in ["manual", "climb", "repeat"]: return false
	var state: Dictionary = rift_progress[world_id]
	if mode == "repeat" and int(state.highest_clear) <= 0: return false
	state.auto_climb = mode == "climb"
	state.repeat_floor = mode == "repeat"
	if bool(state.repeat_floor): state.selected_floor = clampi(int(state.selected_floor), 1, int(state.highest_clear))
	save_to_disk()
	changed.emit()
	return true

func set_rift_selected_floor(world_id: String, floor: int) -> bool:
	ensure_adventure_layout()
	if not rift_progress.has(world_id): return false
	var state: Dictionary = rift_progress[world_id]
	var maximum := int(state.highest_clear) if bool(state.get("repeat_floor", false)) else int(state.highest_clear) + 1
	state.selected_floor = clampi(floor, 1, maxi(1, maximum))
	save_to_disk()
	return true

func highest_unlocked_stage() -> int:
	ensure_world_layout()
	return mini(MAIN_STAGE_LIMIT, completed_stages.size() + 1)

func main_stage_limit() -> int:
	return MAIN_STAGE_LIMIT

func is_stage_complete(stage: int) -> bool:
	return stage in completed_stages

func can_enter_stage(stage: int) -> bool:
	ensure_world_layout()
	if stage < 1 or stage > MAIN_STAGE_LIMIT:
		return false
	return stage <= highest_unlocked_stage()

func world_unlocked(world_name: String) -> bool:
	var required: int = int({"三国":0, "宝可梦":10, "龙族":20, "逆水寒":30, "魔兽世界":40, "金庸":50, "秦时明月":60, "火影忍者":70, "黄易":80, "风云":90}.get(world_name, 9999))
	return required == 0 or is_stage_complete(int(required))

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
	var legendary_gate := {"lu_bu":"lu_bu", "mewtwo":"mewtwo", "zero":"nidhogg", "nine_spirits":"liuxingwen", "hy_ling_donglai":"pang_ban", "fy_di_shitian":"di_shitian"}
	if legendary_gate.has(actor_id) and not bool(boss_first_clear.get(legendary_gate[actor_id], false)):
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

func add_team_experience(amount: int, autosave: bool = true, source: String = "combat") -> bool:
	if amount <= 0:
		return false
	ensure_growth_layout()
	var cap := actor_level_cap()
	if team_level >= cap:
		var storage_limit := floori(experience_to_next(team_level) * float(progression_config.get("cap_storage_ratio", 0.25)))
		team_exp = mini(storage_limit, team_exp + amount)
		_sync_team_progression_mirrors()
		if autosave: changed.emit(); save_to_disk()
		return false
	team_exp += amount
	var leveled := false
	var maximum := int(progression_config.get("max_actor_level", 80))
	while team_level < mini(maximum, cap):
		var needed := experience_to_next(team_level)
		if team_exp < needed:
			break
		team_exp -= needed
		team_level += 1
		team_level_history.push_front({"level": team_level, "time": int(Time.get_unix_time_from_system()), "source": source})
		if team_level_history.size() > 20:
			team_level_history.resize(20)
		leveled = true
	if team_level >= cap:
		team_exp = mini(team_exp, floori(experience_to_next(team_level) * float(progression_config.get("cap_storage_ratio", 0.25))))
	_sync_team_progression_mirrors()
	if autosave:
		changed.emit()
		save_to_disk()
	return leveled

func add_actor_experience(actor_id: String, amount: int, autosave: bool = true, source: String = "combat") -> bool:
	# Compatibility entry point: actor_id is validated but never selects a
	# separate experience pool.
	if actor_id not in ALL_HERO_IDS:
		return false
	return add_team_experience(amount, autosave, source)

func base_experience_to_next(level: int) -> int:
	var curve: Dictionary = progression_config.get("experience_curve", {})
	return int(curve.get("base", 180)) + level * int(curve.get("linear", 90)) + level * level * int(curve.get("quadratic", 25))

func experience_to_next(level: int) -> int:
	return ceili(base_experience_to_next(level) * 1.5)

func actor_level_cap() -> int:
	return clampi(maxi(1, completed_stages.size()), 1, int(progression_config.get("max_actor_level", 80)))

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

func actor_level(_actor_id: String = "") -> int:
	return maxi(1, team_level)

func party_average_level() -> float:
	return float(team_level)

func _sync_team_progression_mirrors() -> void:
	for actor_id in ALL_HERO_IDS:
		actor_levels[actor_id] = team_level
		actor_experience[actor_id] = team_exp
		level_history[actor_id] = team_level_history.duplicate(true)

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
	if not equipped_general_skills.has(actor_id): return result
	for skill_id in equipped_general_skills[actor_id].get(category, []):
		if not str(skill_id).is_empty(): result.append(str(skill_id))
	return result

func general_skill_level(actor_id: String, skill_id: String) -> int:
	return maxi(1, int(general_skill_levels.get(actor_id, {}).get(skill_id, 1)))

func general_skill_max_level() -> int:
	return int(progression_config.get("general_skill_upgrade", {}).get("max_level", 10))

func general_skill_upgrade_cost(actor_id: String, skill_id: String) -> int:
	var level := general_skill_level(actor_id, skill_id)
	var config: Dictionary = progression_config.get("general_skill_upgrade", {})
	return int(config.get("gold_base", 80)) + level * int(config.get("gold_linear", 55)) + level * level * int(config.get("gold_quadratic", 10))

func upgrade_general_skill(actor_id: String, skill_id: String) -> bool:
	if skill_id not in learned_general_skills.get(actor_id, []):
		return false
	var level := general_skill_level(actor_id, skill_id)
	if level >= general_skill_max_level():
		return false
	var cost_gold := general_skill_upgrade_cost(actor_id, skill_id)
	if gold < cost_gold:
		return false
	gold -= cost_gold
	general_skill_levels[actor_id][skill_id] = level + 1
	record_transaction("通用技能升级", "%s:%s Lv.%d（仅金币）" % [actor_id, skill_id, level + 1], -cost_gold)
	changed.emit()
	save_to_disk()
	return true

func recycle_skill_book(skill_id: String, amount: int = 1) -> int:
	if amount <= 0 or skill_book_count(skill_id) < amount:
		return 0
	var unit_gold := int(progression_config.get("general_skill_upgrade", {}).get("duplicate_book_recycle_gold", 45))
	var earned := unit_gold * amount
	skill_books[skill_id] = skill_book_count(skill_id) - amount
	gold += earned
	record_transaction("回收技能书", "%s ×%d" % [skill_id, amount], earned)
	changed.emit()
	save_to_disk()
	return earned

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
	if is_stage_complete(20): pending_offline.dragon_blood_crystal = maxi(int(pending_offline.get("dragon_blood_crystal", 0)), seconds / 360)
	if is_stage_complete(30): pending_offline.jianghu_token = maxi(int(pending_offline.get("jianghu_token", 0)), seconds / 420)
	if is_stage_complete(40): pending_offline.azeroth_token = maxi(int(pending_offline.get("azeroth_token", 0)), seconds / 480)
	if is_stage_complete(50): pending_offline.wuxia_token = maxi(int(pending_offline.get("wuxia_token", 0)), seconds / 540)
	if is_stage_complete(60): pending_offline.qin_moon_token = maxi(int(pending_offline.get("qin_moon_token", 0)), seconds / 600)
	if is_stage_complete(70): pending_offline.ninja_scroll = maxi(int(pending_offline.get("ninja_scroll", 0)), seconds / 660)
	if is_stage_complete(80): pending_offline.huangyi_token = maxi(int(pending_offline.get("huangyi_token", 0)), seconds / 720)
	if is_stage_complete(90): pending_offline.fengyun_token = maxi(int(pending_offline.get("fengyun_token", 0)), seconds / 780)
	return pending_offline

func claim_offline_rewards() -> Dictionary:
	var reward: Dictionary = pending_offline.duplicate(true)
	if int(reward.get("seconds", 0)) <= 0:
		return {}
	gold += int(reward.get("gold", 0))
	materials["three_kingdoms_token"] = int(materials.get("three_kingdoms_token", 0)) + int(reward.get("three_kingdoms_token", 0))
	materials["pokemon_token"] = int(materials.get("pokemon_token", 0)) + int(reward.get("pokemon_token", 0))
	materials["dragon_blood_crystal"] = int(materials.get("dragon_blood_crystal", 0)) + int(reward.get("dragon_blood_crystal", 0))
	materials["jianghu_token"] = int(materials.get("jianghu_token", 0)) + int(reward.get("jianghu_token", 0))
	materials["azeroth_token"] = int(materials.get("azeroth_token", 0)) + int(reward.get("azeroth_token", 0))
	materials["wuxia_token"] = int(materials.get("wuxia_token", 0)) + int(reward.get("wuxia_token", 0))
	materials["qin_moon_token"] = int(materials.get("qin_moon_token", 0)) + int(reward.get("qin_moon_token", 0))
	materials["ninja_scroll"] = int(materials.get("ninja_scroll", 0)) + int(reward.get("ninja_scroll", 0))
	materials["huangyi_token"] = int(materials.get("huangyi_token", 0)) + int(reward.get("huangyi_token", 0))
	materials["fengyun_token"] = int(materials.get("fengyun_token", 0)) + int(reward.get("fengyun_token", 0))
	pending_offline = {"seconds":0,"gold":0,"three_kingdoms_token":0,"pokemon_token":0,"dragon_blood_crystal":0,"jianghu_token":0,"azeroth_token":0,"wuxia_token":0,"qin_moon_token":0,"ninja_scroll":0,"huangyi_token":0,"fengyun_token":0}
	last_seen_unix = int(Time.get_unix_time_from_system())
	record_transaction("离线收益", "%d秒" % int(reward.seconds), int(reward.gold))
	changed.emit()
	save_to_disk()
	return reward

func set_combat_difficulty(value: float, autosave: bool = true) -> float:
	combat_difficulty = snappedf(clampf(value, 0.5, 5.0), 0.1)
	difficulty_config_version = DIFFICULTY_CONFIG_VERSION
	changed.emit()
	if autosave: save_to_disk()
	return combat_difficulty

func reset_to_new_game() -> bool:
	materials = {"salvage_dust": 0, "three_kingdoms_token": 150, "pokemon_token": 0, "dragon_blood_crystal": 0, "jianghu_token": 0, "azeroth_token": 0, "wuxia_token": 0, "qin_moon_token": 0, "ninja_scroll": 0, "huangyi_token": 0, "fengyun_token": 0}
	gold = 0
	guide_step = 0
	guide_finished = false
	guide_skipped = false
	guide_replay = false
	roster = ["liu_bei"]
	party = ["liu_bei", "", "", ""]
	boss_first_clear = {"lu_bu": false, "mewtwo": false, "nidhogg": false, "liuxingwen": false, "lich_king": false, "dongfang_bubai": false, "donghuang_taiyi": false, "madara": false, "pang_ban": false, "di_shitian": false}
	strategy_presets = {"稳健": {"self_hp": 0.45, "ally_hp": 0.65, "enemy_count": 1}, "猛攻": {"self_hp": 0.25, "ally_hp": 0.40, "enemy_count": 2}}
	active_strategy = "稳健"
	team_level = 1
	team_exp = 0
	team_progression_version = TEAM_PROGRESSION_VERSION
	team_level_history = []
	actor_levels = {}
	actor_experience = {}
	skill_levels = {}
	transaction_log = []
	pending_offline = {"seconds": 0, "gold": 0, "three_kingdoms_token": 0, "pokemon_token": 0, "dragon_blood_crystal": 0, "jianghu_token": 0, "azeroth_token":0, "wuxia_token":0, "qin_moon_token":0, "ninja_scroll":0, "huangyi_token":0, "fengyun_token":0}
	last_seen_unix = int(Time.get_unix_time_from_system())
	completed_stages = []
	pokemon_world_unlocked = false
	last_stage_id = "hulao_pass"
	level_history = {}
	learned_general_skills = {}
	equipped_general_skills = {}
	general_skill_levels = {}
	skill_priorities = {}
	skill_books = {}
	special_items = {"recruit_ticket": 0, "camp_coupon": 0, "rift_key": 0}
	collectibles = {}
	rift_progress = {
		"three_kingdoms": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
		"pokemon": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
		"dragon": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []},
		"nsh": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"wow": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"jinyong": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"qin": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"naruto": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"huangyi": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
		,"fengyun": {"highest_clear": 0, "selected_floor": 1, "auto_climb": true, "first_clear_claimed": []}
	}
	encounter_state = {"last_trigger_unix": 0, "active": {}, "merchant_stock": [], "merchant_expiry": 0, "serial": 0}
	encounter_log = []
	encounter_counts = {}
	camp_inventory = {"camp_flag": 1, "campfire": 1, "tent": 1, "bench": 1}
	camp_layout = []
	achievements = {}
	auto_push = true
	combat_difficulty = 1.0
	difficulty_config_version = DIFFICULTY_CONFIG_VERSION
	auto_equipment_settings = default_auto_equipment_settings()
	ensure_growth_layout()
	ensure_world_layout()
	ensure_adventure_layout()
	changed.emit()
	return save_to_disk()

func save_to_disk() -> bool:
	last_seen_unix = maxi(last_seen_unix, int(Time.get_unix_time_from_system()))
	var payload := {"version": VERSION, "team_progression_version": TEAM_PROGRESSION_VERSION, "team_level": team_level, "team_exp": team_exp, "team_level_history": team_level_history, "materials": materials, "gold": gold, "roster": roster, "party": party, "boss_first_clear": boss_first_clear, "strategy_presets": strategy_presets, "active_strategy": active_strategy, "guide_step": guide_step, "guide_finished": guide_finished, "guide_skipped": guide_skipped, "guide_replay": guide_replay, "skill_levels": skill_levels, "learned_general_skills": learned_general_skills, "equipped_general_skills": equipped_general_skills, "general_skill_levels": general_skill_levels, "skill_priorities": skill_priorities, "skill_books": skill_books, "special_items": special_items, "collectibles": collectibles, "rift_progress": rift_progress, "encounter_state": encounter_state, "encounter_log": encounter_log, "encounter_counts": encounter_counts, "camp_inventory": camp_inventory, "camp_layout": camp_layout, "achievements": achievements, "auto_push": auto_push, "combat_difficulty": combat_difficulty, "difficulty_config_version": difficulty_config_version, "auto_equipment_settings": auto_equipment_settings, "transaction_log": transaction_log, "pending_offline": pending_offline, "last_seen_unix": last_seen_unix, "completed_stages": completed_stages, "pokemon_world_unlocked": pokemon_world_unlocked, "last_stage_id": last_stage_id}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("无法写入进度存档: " + save_path)
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	return true

func _migrate_legacy_team_progression(parsed: Dictionary) -> void:
	var legacy_levels = parsed.get("actor_levels", {})
	var legacy_experience = parsed.get("actor_experience", {})
	if typeof(legacy_levels) != TYPE_DICTIONARY:
		legacy_levels = {}
	if typeof(legacy_experience) != TYPE_DICTIONARY:
		legacy_experience = {}
	var source_actor := ""
	var source_ratio := -1.0
	team_level = 1
	for actor_id in legacy_levels:
		var legacy_level := maxi(1, int(legacy_levels[actor_id]))
		var legacy_needed := maxf(1.0, float(base_experience_to_next(legacy_level)))
		var ratio := clampf(float(legacy_experience.get(actor_id, 0)) / legacy_needed, 0.0, 0.999999)
		if legacy_level > team_level or (legacy_level == team_level and ratio > source_ratio):
			team_level = legacy_level
			source_actor = str(actor_id)
			source_ratio = ratio
	team_level = clampi(team_level, 1, int(progression_config.get("max_actor_level", 80)))
	team_exp = roundi(maxf(0.0, source_ratio) * experience_to_next(team_level))
	team_exp = mini(team_exp, maxi(0, experience_to_next(team_level) - 1))
	team_level_history = []
	var legacy_history = parsed.get("level_history", {})
	if not source_actor.is_empty() and typeof(legacy_history) == TYPE_DICTIONARY:
		var source_history = legacy_history.get(source_actor, [])
		if typeof(source_history) == TYPE_ARRAY:
			team_level_history = source_history.duplicate(true)
	if team_level_history.size() > 20:
		team_level_history.resize(20)

func load_from_disk() -> bool:
	var source_path := save_path
	if not FileAccess.file_exists(source_path) and save_path == NORMAL_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_V09_PATH):
		if not FileAccess.file_exists(MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_V09_PATH), ProjectSettings.globalize_path(MIGRATION_BACKUP_PATH))
		source_path = LEGACY_V09_PATH
	elif not FileAccess.file_exists(source_path) and save_path == NORMAL_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_V08_PATH):
		if not FileAccess.file_exists(MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_V08_PATH), ProjectSettings.globalize_path(MIGRATION_BACKUP_PATH))
		source_path = LEGACY_V08_PATH
	elif not FileAccess.file_exists(source_path) and save_path == NORMAL_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_PATH):
		if not FileAccess.file_exists(MIGRATION_BACKUP_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_PATH), ProjectSettings.globalize_path(MIGRATION_BACKUP_PATH))
		source_path = LEGACY_PATH
	elif not FileAccess.file_exists(source_path) and save_path == NORMAL_PATH and not FileAccess.file_exists(RESET_MARKER_PATH) and FileAccess.file_exists(LEGACY_V061_PATH):
		source_path = LEGACY_V061_PATH
	if not FileAccess.file_exists(source_path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if typeof(parsed) == TYPE_DICTIONARY and int(parsed.get("team_progression_version", 0)) < TEAM_PROGRESSION_VERSION and save_path == NORMAL_PATH and not FileAccess.file_exists(TEAM_MIGRATION_BACKUP_PATH):
		var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source_path), ProjectSettings.globalize_path(TEAM_MIGRATION_BACKUP_PATH))
		if backup_error != OK:
			push_error("无法备份旧等级存档，已取消共享等级迁移。错误码：%d" % backup_error)
			return false
	return apply_payload(parsed)

func apply_payload(parsed) -> bool:
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var payload_version := str(parsed.get("version", ""))
	if payload_version not in [VERSION, "0.9", "0.8", "0.7", "0.6.1"]:
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
	var migrated_team_progression := int(parsed.get("team_progression_version", 0)) < TEAM_PROGRESSION_VERSION
	if migrated_team_progression:
		_migrate_legacy_team_progression(parsed)
	else:
		team_level = clampi(int(parsed.get("team_level", 1)), 1, int(progression_config.get("max_actor_level", 80)))
		team_exp = maxi(0, int(parsed.get("team_exp", 0)))
		team_level_history = parsed.get("team_level_history", [])
		if typeof(team_level_history) != TYPE_ARRAY:
			team_level_history = []
	team_progression_version = TEAM_PROGRESSION_VERSION
	actor_levels = {}
	actor_experience = {}
	skill_levels = parsed.get("skill_levels", {})
	level_history = {}
	learned_general_skills = parsed.get("learned_general_skills", {})
	equipped_general_skills = parsed.get("equipped_general_skills", {})
	general_skill_levels = parsed.get("general_skill_levels", {})
	skill_priorities = parsed.get("skill_priorities", {})
	skill_books = parsed.get("skill_books", {})
	special_items.merge(parsed.get("special_items", {}), true)
	collectibles = parsed.get("collectibles", {})
	rift_progress.merge(parsed.get("rift_progress", {}), true)
	encounter_state.merge(parsed.get("encounter_state", {}), true)
	encounter_log = parsed.get("encounter_log", [])
	encounter_counts = parsed.get("encounter_counts", {})
	camp_inventory.merge(parsed.get("camp_inventory", {}), true)
	camp_layout = parsed.get("camp_layout", [])
	achievements = parsed.get("achievements", {})
	auto_push = bool(parsed.get("auto_push", true))
	auto_equipment_settings = default_auto_equipment_settings()
	var stored_auto_settings = parsed.get("auto_equipment_settings", {})
	if typeof(stored_auto_settings) == TYPE_DICTIONARY:
		for key in auto_equipment_settings:
			if stored_auto_settings.has(key):
				auto_equipment_settings[key] = stored_auto_settings[key]
	for bool_key in ["sell_enabled", "dismantle_enabled", "keep_special_effects"]:
		auto_equipment_settings[bool_key] = bool(auto_equipment_settings[bool_key])
	for quality_key in ["sell_max_quality", "dismantle_max_quality"]:
		if str(auto_equipment_settings[quality_key]) not in ["white", "green", "blue", "purple", "orange"]:
			auto_equipment_settings[quality_key] = "white"
	if str(auto_equipment_settings.priority) not in ["dismantle", "sell"]:
		auto_equipment_settings.priority = "dismantle"
	transaction_log = parsed.get("transaction_log", [])
	if migrated_team_progression:
		record_transaction("等级系统迁移", "原角色最高等级已转换为冒险团共享Lv.%d" % team_level, 0)
	var stored_difficulty_version := int(parsed.get("difficulty_config_version", 1))
	if stored_difficulty_version < DIFFICULTY_CONFIG_VERSION:
		var legacy_difficulty := float(parsed.get("combat_difficulty", 1.5))
		combat_difficulty = snappedf(clampf(legacy_difficulty / LEGACY_DIFFICULTY_BASE, 0.5, 5.0), 0.1)
		difficulty_config_version = DIFFICULTY_CONFIG_VERSION
		record_transaction("难度配置迁移", "旧版 %.1f× → 新版 %.1f×（新版1.0×=旧版2.5×）" % [legacy_difficulty, combat_difficulty], 0)
	else:
		combat_difficulty = snappedf(clampf(float(parsed.get("combat_difficulty", 1.0)), 0.5, 5.0), 0.1)
		difficulty_config_version = DIFFICULTY_CONFIG_VERSION
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
	ensure_adventure_layout()
	return true
