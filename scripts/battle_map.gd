class_name BattleMap
extends Node2D

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")

const ARENA_SIZE := Vector2(1060, 520)
# V1.0 uses an unobstructed arena in every mode. Keep the collection for
# compatibility with older callers, but never populate fixed blockers.
var obstacles: Array[Rect2] = []
var rally_position := Vector2(-100, -100)
var map_id := "hulao_pass"

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var ground: Texture2D = ArtCatalogScript.texture("maps_ground", map_id)
	if ground != null:
		draw_texture_rect(ground, Rect2(Vector2.ZERO, ARENA_SIZE), false)
	else:
		var palette := world_palette()
		draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), palette[0], true)
		for x in range(0, int(ARENA_SIZE.x), 64):
			for y in range(0, int(ARENA_SIZE.y), 64):
				var checker := int(x / 64) + int(y / 64)
				var tile_color: Color = palette[1] if checker % 2 == 0 else palette[2]
				draw_rect(Rect2(x, y, 64, 64), tile_color, true)
		# River and stepping stones are visual flavor and do not affect movement.
		draw_colored_polygon(PackedVector2Array([Vector2(0, 244), Vector2(310, 218), Vector2(700, 250), Vector2(1060, 226), Vector2(1060, 294), Vector2(700, 316), Vector2(310, 282), Vector2(0, 306)]), palette[3])
		for x in range(110, 1000, 170):
			draw_circle(Vector2(x, 268 + sin(float(x)) * 8), 12, Color("#D5D6B2"))
	var decor: Texture2D = ArtCatalogScript.texture("maps_decor", map_id)
	if decor != null:
		draw_texture_rect(decor, Rect2(Vector2.ZERO, ARENA_SIZE), false)
	if rally_position.x >= 0:
		draw_circle(rally_position, 18, Color(1, 1, 1, 0.16), true)
		draw_arc(rally_position, 18, 0, TAU, 32, Color("#FFF6A2"), 3)
		draw_line(rally_position - Vector2(8, 0), rally_position + Vector2(8, 0), Color.WHITE, 2)
		draw_line(rally_position - Vector2(0, 8), rally_position + Vector2(0, 8), Color.WHITE, 2)

func world_palette() -> Array[Color]:
	if map_id.begins_with("naruto_"):
		return [Color("#59676A"), Color("#516064"), Color("#637276"), Color("#779DA5")]
	if map_id.begins_with("qin_"):
		return [Color("#777266"), Color("#6F6A5E"), Color("#817B6E"), Color("#7695A0")]
	if map_id in ["elwynn_forest","deadmines","scarlet_monastery","stratholme","molten_core","naxxramas","ulduar","shadow_council","dragon_soul","frozen_throne"]:
		return [Color("#44505A"), Color("#3C4852"), Color("#4C5963"), Color("#597D8A")]
	if map_id in ["niujia_night","baituo_manor","ancient_tomb_edge","xiangyang_outskirts","emei_summit","bright_peak_passage","shaolin_temple","swallow_manor","black_wood_path","black_wood_summit"]:
		return [Color("#8B9274"), Color("#81896B"), Color("#959C7F"), Color("#6B91A0")]
	if map_id in ["cassell_academy","bronze_city_outskirts","tokyo_paradise","nibelungen_gate","bronze_throne","bronze_city_depths","underground_dragon_lair","nibelungen_core","white_king_relic","black_king_throne"]:
		return [Color("#424958"), Color("#3B4352"), Color("#4A5262"), Color("#7B493E")]
	if map_id in ["wuyang_outer","wuyang_tunnel","wuyang_gate","wuyang_inner","thunder_music_array","wuyang_final","mirror_outer","mirror_illusion","mirror_forbidden","mirror_summit"]:
		return [Color("#9FB18B"), Color("#94A77F"), Color("#A9B993"), Color("#6E9DA4")]
	if map_id in ["viridian_forest","pewter_trail","moon_mountain","cerulean_river","power_plant","lavender_tower","saffron_street","victory_road","unknown_depths","cerulean_cave"]:
		return [Color("#8BC6A2"), Color("#7FBA96"), Color("#96CEAA"), Color("#5DAED1")]
	return [Color("#B6A66E"), Color("#AE9D67"), Color("#BFAF79"), Color("#6F9FB1")]

func set_rally(point: Vector2) -> void:
	rally_position = point
	queue_redraw()

