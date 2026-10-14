class_name ResetManager
extends RefCounted

var last_error := ""
var backup_root := "user://backups"

func perform_safe_reset(progression, inventory) -> Dictionary:
	last_error = ""
	var backup := create_verified_backup()
	if not bool(backup.get("ok", false)):
		return {"ok": false, "error": last_error}
	var marker_path := "user://wanjie_reset_test_marker.json" if str(progression.save_path).contains("test") else "user://wanjie_reset_marker.json"
	if not _write_reset_marker(marker_path, str(backup.path)):
		last_error = "无法写入重开迁移阻断标记，已取消重置。"
		return {"ok": false, "error": last_error, "backup_path": backup.path}
	var progress_saved: bool = progression.reset_to_new_game()
	var inventory_saved: bool = inventory.reset_to_new_game()
	if not progress_saved or not inventory_saved or not _validate_new_game(progression.save_path, inventory.save_path):
		last_error = "新开局存档写入或校验失败，正在恢复重置前存档。"
		_restore_backup(backup, [progression.save_path, inventory.save_path, marker_path])
		return {"ok": false, "error": last_error, "backup_path": backup.path, "reload_required": true}
	return {"ok": true, "backup_path": backup.path, "marker_path": marker_path}

func create_verified_backup() -> Dictionary:
	var user_dir := DirAccess.open("user://")
	if user_dir == null:
		last_error = "无法访问Godot用户存档目录。"
		return {"ok": false}
	var stamp_data := Time.get_datetime_dict_from_system()
	var stamp := "%04d%02d%02d_%02d%02d%02d" % [stamp_data.year, stamp_data.month, stamp_data.day, stamp_data.hour, stamp_data.minute, stamp_data.second]
	var backup_path := backup_root.trim_suffix("/") + "/reset_" + stamp
	var suffix := 1
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(backup_path)):
		backup_path = backup_root.trim_suffix("/") + "/reset_%s_%d" % [stamp, suffix]
		suffix += 1
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if DirAccess.make_dir_recursive_absolute(backup_absolute) != OK:
		last_error = "无法创建存档备份目录：" + backup_path
		return {"ok": false}
	var names: Array[String] = []
	user_dir.list_dir_begin()
	var name := user_dir.get_next()
	while not name.is_empty():
		if not user_dir.current_is_dir() and name.begins_with("wanjie_") and name.ends_with(".json"):
			names.append(name)
		name = user_dir.get_next()
	user_dir.list_dir_end()
	names.sort()
	for file_name in names:
		var source := ProjectSettings.globalize_path("user://" + file_name)
		var destination := backup_absolute.path_join(file_name)
		if DirAccess.copy_absolute(source, destination) != OK or not _files_identical(source, destination):
			last_error = "备份文件复制校验失败：" + file_name
			return {"ok": false, "path": backup_path, "files": names}
	var manifest := {"version": "0.8.1", "created_unix": int(Time.get_unix_time_from_system()), "source_files": names}
	var manifest_path := backup_absolute.path_join("backup_manifest.json")
	var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if manifest_file == null:
		last_error = "无法写入备份清单。"
		return {"ok": false, "path": backup_path, "files": names}
	manifest_file.store_string(JSON.stringify(manifest, "  "))
	manifest_file.close()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("source_files", []) != names:
		last_error = "备份清单校验失败。"
		return {"ok": false, "path": backup_path, "files": names}
	return {"ok": true, "path": backup_path, "absolute_path": backup_absolute, "files": names}

func _write_reset_marker(path: String, backup_path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version": "0.8.1", "reset_unix": int(Time.get_unix_time_from_system()), "backup_path": backup_path}, "  "))
	file.close()
	return typeof(JSON.parse_string(FileAccess.get_file_as_string(path))) == TYPE_DICTIONARY

func _validate_new_game(progress_path: String, inventory_path: String) -> bool:
	if not FileAccess.file_exists(progress_path) or not FileAccess.file_exists(inventory_path): return false
	var progress = JSON.parse_string(FileAccess.get_file_as_string(progress_path))
	var inventory = JSON.parse_string(FileAccess.get_file_as_string(inventory_path))
	if typeof(progress) != TYPE_DICTIONARY or typeof(inventory) != TYPE_DICTIONARY: return false
	return progress.get("roster", []) == ["liu_bei"] \
		and progress.get("party", []) == ["liu_bei", "", "", ""] \
		and int(progress.get("gold", -1)) == 0 \
		and int(progress.get("materials", {}).get("three_kingdoms_token", -1)) == 150 \
		and progress.get("completed_stages", []) == [] \
		and is_equal_approx(float(progress.get("combat_difficulty", 0.0)), 1.5) \
		and inventory.get("items", []) == []

func _restore_backup(backup: Dictionary, generated_paths: Array) -> void:
	var names: Array = backup.get("files", [])
	var backup_absolute := str(backup.get("absolute_path", ""))
	for path in generated_paths:
		var file_name := str(path).get_file()
		if file_name not in names and FileAccess.file_exists(str(path)):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(path)))
	for file_name in names:
		DirAccess.copy_absolute(backup_absolute.path_join(str(file_name)), ProjectSettings.globalize_path("user://" + str(file_name)))

func _files_identical(first: String, second: String) -> bool:
	if not FileAccess.file_exists(first) or not FileAccess.file_exists(second): return false
	return FileAccess.get_file_as_bytes(first) == FileAccess.get_file_as_bytes(second)
