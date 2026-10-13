class_name ArtCatalog
extends RefCounted

const CONFIG_PATH := "res://data/art_resources.json"
static var _config: Dictionary = {}
static var _cache: Dictionary = {}

static func reload() -> void:
	_config.clear()
	_cache.clear()
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_config = parsed

static func texture(group: String, key: String) -> Texture2D:
	if _config.is_empty():
		reload()
	var path: String = str(_config.get(group, {}).get(key, ""))
	if path.is_empty() or not path.begins_with("res://"):
		return null
	if _cache.has(path):
		return _cache[path]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			result = resource
	_cache[path] = result
	return result
