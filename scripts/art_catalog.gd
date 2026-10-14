class_name ArtCatalog
extends RefCounted

const CONFIG_PATH := "res://data/art_resources.json"
static var _config: Dictionary = {}
static var _cache: Dictionary = {}
static var _missing_logged: Dictionary = {}

static func reload() -> void:
	_config.clear()
	_cache.clear()
	_missing_logged.clear()
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_config = parsed

static func texture(group: String, key: String) -> Texture2D:
	if _config.is_empty():
		reload()
	var path: String = str(_config.get(group, {}).get(key, ""))
	if path.is_empty() or not path.begins_with("res://"):
		_log_missing_once(group, key, "未配置有效的 res:// 路径")
		return null
	var cache_key := group + ":" + key
	if _cache.has(cache_key):
		return _cache[cache_key]
	var result: Texture2D = null
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is Texture2D:
			result = resource
	if result == null:
		_log_missing_once(group, key, "资源不存在或不是Texture2D：" + path)
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

static func portrait(actor_id: String) -> Texture2D:
	# Portraits are actor-specific. Missing art deliberately returns null so the
	# caller shows that actor's own placeholder instead of another hero's image.
	return texture("portraits", actor_id)

static func configured_path(group: String, key: String) -> String:
	if _config.is_empty(): reload()
	return str(_config.get(group, {}).get(key, ""))

static func layout(group: String, key: String) -> Dictionary:
	if _config.is_empty(): reload()
	var value = _config.get(group + "_layouts", {}).get(key, {})
	return value.duplicate(true) if typeof(value) == TYPE_DICTIONARY else {}

static func _log_missing_once(group: String, key: String, reason: String) -> void:
	# Function icons, maps and most battle units intentionally use code-drawn
	# placeholders. Only missing character portraits are actionable art gaps.
	if group != "portraits" or key.is_empty(): return
	var cache_key := group + ":" + key
	if _missing_logged.has(cache_key): return
	_missing_logged[cache_key] = true
	push_warning("ART_RESOURCE_MISSING %s/%s：%s" % [group, key, reason])
