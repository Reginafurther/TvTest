extends SceneTree

const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")

class FakeInventory:
	extends RefCounted
	func get_actor_stats(_actor_id: String) -> Dictionary:
		return {}

class FakeBattle:
	extends RefCounted
	var progression
	var inventory := FakeInventory.new()
	var equipment_config := {"rules": {}}

func _initialize() -> void:
	var failures: Array[String] = []
	var progression = ProgressionManagerScript.new()
	progression.progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	progression.completed_stages = range(1, 11)
	progression.ensure_world_layout()
	progression.ensure_growth_layout()
	var base_needed: int = progression.base_experience_to_next(1)
	if progression.experience_to_next(1) != ceili(base_needed * 1.5):
		failures.append("共享升级门槛不是原单角色门槛的1.5倍")
	if progression.actor_level("liu_bei") != 1 or progression.actor_level("naruto_tsunade") != 1:
		failures.append("已招募与未招募角色未共享等级")
	var needed: int = progression.experience_to_next(1)
	if progression.add_team_experience(needed - 1, false, "test"):
		failures.append("未达到门槛时错误升级")
	if not progression.add_team_experience(1, false, "test") or progression.team_level != 2 or progression.team_exp != 0:
		failures.append("共享经验未正确触发升级")
	if progression.actor_level("zhao_yun") != 2 or progression.actor_level("qin_xiaomeng") != 2:
		failures.append("全角色等级镜像未同步")

	var fake_battle := FakeBattle.new()
	fake_battle.progression = progression
	var hero = BattleUnitScript.new()
	hero.battle = fake_battle
	hero.faction = "heroes"
	hero.actor_id = "zhao_yun"
	hero.actor_data = {"max_hp": 100.0, "attack": 10.0, "defense": 5.0, "attack_interval": 1.0}
	hero.passive_data = {}
	hero.base_attack_interval = 1.0
	hero.max_hp = 100.0
	hero.hp = 100.0
	hero.refresh_progression_stats()
	if not is_equal_approx(hero.attack, 10.6) or not is_equal_approx(hero.max_hp, 108.0):
		failures.append("共享升级后角色成长属性未刷新")
	hero.free()

	var legacy_level := 7
	var legacy_base_needed: int = progression.base_experience_to_next(legacy_level)
	var legacy_exp := floori(legacy_base_needed * 0.4)
	var migrated = ProgressionManagerScript.new()
	migrated.progression_config = progression.progression_config
	var legacy_payload := {
		"version": "1.0",
		"gold": 321,
		"roster": ["liu_bei", "zhao_yun"],
		"party": ["liu_bei", "zhao_yun", "", ""],
		"actor_levels": {"liu_bei": 3, "zhao_yun": legacy_level},
		"actor_experience": {"liu_bei": 20, "zhao_yun": legacy_exp},
		"completed_stages": range(1, 11)
	}
	if not migrated.apply_payload(legacy_payload):
		failures.append("旧存档迁移失败")
	else:
		var expected_exp := roundi((float(legacy_exp) / legacy_base_needed) * migrated.experience_to_next(legacy_level))
		if migrated.team_level != legacy_level or migrated.team_exp != expected_exp:
			failures.append("旧存档最高等级或经验比例迁移错误")
		if migrated.gold != 321 or migrated.roster != legacy_payload.roster:
			failures.append("迁移损坏了非等级进度")

	var normal_path: String = ProgressionManagerScript.NORMAL_PATH
	var backup_path: String = ProgressionManagerScript.TEAM_MIGRATION_BACKUP_PATH
	for path in [normal_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var legacy_file := FileAccess.open(normal_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_payload))
	legacy_file.close()
	var disk_migration = ProgressionManagerScript.new()
	disk_migration.progression_config = progression.progression_config
	if not disk_migration.load_from_disk() or not FileAccess.file_exists(backup_path):
		failures.append("迁移读取前未建立旧存档备份")
	else:
		var migrated_level: int = int(disk_migration.team_level)
		var migrated_exp: int = int(disk_migration.team_exp)
		disk_migration.save_to_disk()
		var reload_migration = ProgressionManagerScript.new()
		reload_migration.progression_config = progression.progression_config
		if not reload_migration.load_from_disk() or reload_migration.team_level != migrated_level or reload_migration.team_exp != migrated_exp:
			failures.append("共享等级迁移被重复执行")
		reload_migration.free()
	disk_migration.free()
	for path in [normal_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	progression.save_path = "user://team_progression_validation.json"
	progression.save_to_disk()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(progression.save_path))
	if typeof(saved) != TYPE_DICTIONARY or saved.has("actor_levels") or saved.has("actor_experience") or int(saved.get("team_level", 0)) != 2:
		failures.append("新存档仍写入独立角色等级或遗漏共享等级")
	if FileAccess.file_exists(progression.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progression.save_path))
	progression.free()
	migrated.free()
	if failures.is_empty():
		print("TEAM_PROGRESSION_VALIDATION_PASS shared_level=true single_pool=true threshold=1.5 migration=true stat_refresh=true")
	else:
		for failure in failures:
			push_error("TEAM_PROGRESSION_VALIDATION_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
