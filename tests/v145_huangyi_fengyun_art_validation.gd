extends SceneTree

const ArtCatalogScript = preload("res://scripts/art_catalog.gd")
const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")

const CHARACTERS := {
	"hy_long_ying":"龙鹰", "hy_wu_zhao":"武曌", "hy_kou_zhong":"寇仲",
	"hy_xu_ziling":"徐子陵", "hy_wan_wan":"婠婠", "hy_fa_ming":"法明",
	"hy_yan_fei":"燕飞", "hy_sun_en":"孙恩", "hy_ling_donglai":"令东来",
	"hy_lang_fanyun":"浪翻云", "fy_nie_feng":"聂风", "fy_bu_jingyun":"步惊云",
	"fy_wuming":"无名", "fy_sword_saint":"剑圣·独孤剑", "fy_wu_wudi":"武无敌",
	"fy_xiao_wu":"小武", "fy_duan_lang":"断浪", "fy_di_er_meng":"第二梦",
	"fy_jian_chen":"剑晨", "fy_di_shitian":"帝释天"
}

var failures: Array[String] = []

func _initialize() -> void:
	var battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	battle.progression.roster = CHARACTERS.keys()
	battle.progression.party = ["hy_long_ying", "hy_wu_zhao", "fy_nie_feng", "fy_bu_jingyun"]
	battle.progression.ensure_growth_layout()
	var character_ui = CharacterUIScript.new()
	root.add_child(character_ui)
	character_ui.setup(battle)
	ArtCatalogScript.reload()
	for actor_id in CHARACTERS:
		_validate_actor(str(actor_id), str(CHARACTERS[actor_id]), battle, character_ui)
	battle.clear_combatants()
	character_ui.queue_free()
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V145_HUANGYI_FENGYUN_ART_PASS portraits=20 units=20 alpha=true dimensions=640x960/512x512 ui_refresh=true")
		quit(0)
		return
	for failure in failures:
		push_error("V145_HUANGYI_FENGYUN_ART_FAIL: " + failure)
	quit(1)

func _validate_actor(actor_id: String, expected_name: String, battle, character_ui) -> void:
	if not battle.actors.has(actor_id):
		failures.append(actor_id + "不存在于角色配置")
		return
	if str(battle.actors[actor_id].get("name", "")) != expected_name:
		failures.append(actor_id + "角色名称映射错误")
	var world_dir := "huangyi" if actor_id.begins_with("hy_") else "fengyun"
	var portrait_path := "res://assets/portraits/%s/%s_portrait_v1.png" % [world_dir, actor_id]
	var unit_path := "res://assets/units/%s/%s_battle_v1.png" % [world_dir, actor_id]
	if ArtCatalogScript.configured_path("portraits", actor_id) != portrait_path:
		failures.append(actor_id + "角色立绘路径错误")
	if ArtCatalogScript.configured_path("units", actor_id) != unit_path:
		failures.append(actor_id + "战斗立绘路径错误")
	var portrait: Texture2D = ArtCatalogScript.portrait(actor_id)
	var unit_texture: Texture2D = ArtCatalogScript.texture("units", actor_id)
	if portrait == null or portrait.get_width() != 640 or portrait.get_height() != 960:
		failures.append(actor_id + "角色立绘加载或尺寸错误")
	elif portrait.get_image().detect_alpha() == Image.ALPHA_NONE:
		failures.append(actor_id + "角色立绘没有Alpha通道")
	if unit_texture == null or unit_texture.get_width() != 512 or unit_texture.get_height() != 512:
		failures.append(actor_id + "战斗立绘加载或尺寸错误")
	elif unit_texture.get_image().detect_alpha() == Image.ALPHA_NONE:
		failures.append(actor_id + "战斗立绘没有Alpha通道")
	var portrait_layout: Dictionary = ArtCatalogScript.layout("portraits", actor_id)
	var unit_layout: Dictionary = ArtCatalogScript.layout("units", actor_id)
	if portrait_layout.is_empty() or float(portrait_layout.get("scale", 0.0)) <= 0.0:
		failures.append(actor_id + "角色立绘布局缺失")
	if unit_layout.is_empty() or unit_layout.get("anchor", []) != [0.5, 0.98]:
		failures.append(actor_id + "战斗脚底锚点错误")
	character_ui.selected_actor = actor_id
	character_ui.refresh_center()
	if character_ui.portrait_texture.texture != portrait or not character_ui.portrait_texture.visible or character_ui.portrait_placeholder.visible:
		failures.append(actor_id + "角色页面没有刷新到对应立绘")
	var unit = battle.spawn_unit(actor_id, "heroes", Vector2(400, 300))
	if unit == null or ArtCatalogScript.texture("units", unit.actor_id) != unit_texture:
		failures.append(actor_id + "真实战斗单位没有读取对应贴图")
	elif not _has_collision_shape(unit):
		failures.append(actor_id + "战斗贴图接入破坏了单位碰撞节点")
	if is_instance_valid(unit):
		battle.heroes.erase(unit)
		unit.queue_free()


func _has_collision_shape(unit: Node) -> bool:
	for child in unit.get_children():
		if child is CollisionShape2D:
			return true
	return false
