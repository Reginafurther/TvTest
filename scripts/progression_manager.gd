class_name ProgressionManager
extends Node

signal changed
const VERSION := "0.3"
const NORMAL_PATH := "user://wanjie_v03_progress.json"
const TEST_PATH := "user://wanjie_v03_test_progress.json"

var save_path := NORMAL_PATH
var materials := {"salvage_dust": 0, "three_kingdoms_token": 0, "pokemon_token": 0}
var recruit_tokens := 1
var roster: Array = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
var party: Array = ["zhao_yun", "liu_bei", "pikachu", "snorlax"]
var boss_first_clear := {"lu_bu": false, "mewtwo": false}
var strategy_presets := {
	"稳健": {"self_hp": 0.45, "ally_hp": 0.65, "enemy_count": 1},
	"猛攻": {"self_hp": 0.25, "ally_hp": 0.40, "enemy_count": 2}
}
var active_strategy := "稳健"

func setup() -> void:
	if "--v03-test" in OS.get_cmdline_user_args() or "--v03-persist-write" in OS.get_cmdline_user_args() or "--v03-persist-read" in OS.get_cmdline_user_args():
		save_path = TEST_PATH
	if "--v03-test" in OS.get_cmdline_user_args() or "--v03-persist-write" in OS.get_cmdline_user_args():
		clear_test_save()
	load_from_disk()

func clear_test_save() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

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
	changed.emit()
	save_to_disk()
	return id

func exchange_actor(actor_id: String, material_id: String, cost: int) -> bool:
	if actor_id in roster or not spend_material(material_id, cost):
		return false
	roster.append(actor_id)
	changed.emit()
	save_to_disk()
	return true

func unlock_boss_actor(boss_id: String, actor_id: String) -> bool:
	var first := not bool(boss_first_clear.get(boss_id, false))
	if first:
		boss_first_clear[boss_id] = true
		if actor_id not in roster:
			roster.append(actor_id)
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

func save_to_disk() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "materials": materials, "recruit_tokens": recruit_tokens, "roster": roster, "party": party, "boss_first_clear": boss_first_clear, "strategy_presets": strategy_presets, "active_strategy": active_strategy}, "  "))
	return true

func load_from_disk() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	# Missing fields are filled with V0.3 defaults: this is the V0.2A migration path.
	materials.merge(parsed.get("materials", {}), true)
	recruit_tokens = int(parsed.get("recruit_tokens", recruit_tokens))
	roster = parsed.get("roster", roster)
	party = parsed.get("party", party)
	boss_first_clear.merge(parsed.get("boss_first_clear", {}), true)
	strategy_presets.merge(parsed.get("strategy_presets", {}), true)
	active_strategy = parsed.get("active_strategy", active_strategy)
	while party.size() < 4:
		party.append(roster[party.size() % maxi(1, roster.size())])
	return true

