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
	var cache_key := group + ":" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			result = resource
	var crop: Array = _config.get(group + "_regions", {}).get(key, [])
	if result != null and crop.size() == 4:
		var region := Rect2(float(crop[0]), float(crop[1]), float(crop[2]), float(crop[3]))
		if region.position.x >= 0 and region.position.y >= 0 and region.end.x <= result.get_width() and region.end.y <= result.get_height():
			var atlas := AtlasTexture.new()
			atlas.atlas = result
			atlas.region = region
			result = atlas
	_cache[cache_key] = result
	return result
