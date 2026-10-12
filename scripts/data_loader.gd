class_name DataLoader
extends RefCounted

static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("数据文件不存在: " + path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("数据格式错误: " + path)
		return {}
	return parsed

