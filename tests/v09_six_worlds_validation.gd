extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")

var battle
var failures: Array[String] = []

func _initialize() -> void:
	battle = BattleControllerScript.new()
	root.add_child(battle)
	await process_frame
	battle.is_paused = true
	_validate_content_counts()
	_validate_world_progression()
	_validate_stage_pools_and_bosses()
	_validate_new_exclusive_skills()
	_validate_general_skills()
	_validate_rifts_and_save_migration()
	_validate_boss_labels()
	battle.clear_combatants()
	if FileAccess.file_exists(battle.progression.save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(battle.progression.save_path))
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V09_SIX_WORLDS_VALIDATION_PASS worlds=6 stages=60 playable=52 new_actors=16 new_exclusive=16 new_general=32 rifts=6 boss_names=true migration=true")
		quit(0)
		return
	for failure in failures: push_error("V09_SIX_WORLDS_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_content_counts() -> void:
	var playable: Array[String] = []
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if not actor.has("enemy_type") and actor.has("skill") and actor.has("passive_skill"): playable.append(str(actor_id))
	if playable.size() != 52: failures.append("可玩角色不是52名：%d" % playable.size())
	if battle.worlds_config.maps.size() != 60: failures.append("主线地图不是60张：%d" % battle.worlds_config.maps.size())
	var wow_roles := {"tank":0,"healer":0,"support":0,"output":0}
	for actor_id in playable:
		var actor: Dictionary = battle.actors[actor_id]
		if str(actor.get("world", "")) != "魔兽世界": continue
		var role := str(actor.get("combat_role", ""))
		if role in ["tank", "healer", "support"]: wow_roles[role] += 1
		else: wow_roles.output += 1
	if wow_roles != {"tank":1,"healer":1,"support":1,"output":3}: failures.append("魔兽职业比例错误：%s" % wow_roles)
	var jy_count := 0
	for actor_id in playable:
		if str(battle.actors[actor_id].get("world", "")) == "金庸": jy_count += 1
	if jy_count != 10: failures.append("金庸可玩角色不是10名")
	var new_general := 0
	var world_general_counts := {"魔兽世界_active":0,"魔兽世界_passive":0,"金庸_active":0,"金庸_passive":0}
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		var world := str(data.get("world", ""))
		if world in ["魔兽世界", "金庸"]:
			new_general += 1
			world_general_counts[world + "_" + str(data.get("category", ""))] += 1
	if new_general != 32: failures.append("新增通用技能不是32个：%d" % new_general)
	if world_general_counts != {"魔兽世界_active":6,"魔兽世界_passive":6,"金庸_active":10,"金庸_passive":10}: failures.append("新世界通用主动/被动数量错误：%s" % world_general_counts)

func _validate_world_progression() -> void:
	var p = battle.progression
	p.completed_stages = range(1, 40); p.ensure_world_layout()
	if p.can_enter_stage(41) or p.world_unlocked("魔兽世界"): failures.append("未通关40关即可进入魔兽世界")
	p.completed_stages = range(1, 41); p.ensure_world_layout()
	if not p.can_enter_stage(41) or not p.world_unlocked("魔兽世界") or p.world_unlocked("金庸"): failures.append("40关世界解锁边界错误")
	for stage in range(41, 61):
		if battle.stage_id_for_number(stage).is_empty() or not p.complete_stage(stage): failures.append("第%d关无法按顺序完成" % stage)
	if not p.world_unlocked("金庸") or p.can_enter_stage(61) or p.highest_unlocked_stage() != 60: failures.append("50关解锁或60/61关终点防线错误")

func _validate_stage_pools_and_bosses() -> void:
	var seen: Dictionary = {}
	for map_id in battle.worlds_config.maps:
		var data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(data.get("global_stage", 0)); seen[stage] = true
		var pool: Array[String] = battle.valid_mainline_enemy_pool(data)
		if pool.size() != data.get("enemy_pool", []).size(): failures.append("第%d关普通池含Boss或无效模板" % stage)
		for enemy_id in pool:
			var enemy: Dictionary = battle.actors[enemy_id]
			if str(enemy.get("enemy_type", "normal")) == "boss" or enemy.has("boss_id"): failures.append("第%d关普通池含Boss身份" % stage)
		if stage < 41: continue
		battle.clear_combatants(); battle.current_map_id = str(map_id); battle.wave = 1; battle.stage_cleared = false; battle.spawn_wave()
		for enemy in battle.enemies:
			if enemy.enemy_type == "boss" or enemy.actor_data.has("boss_id"): failures.append("第%d关普通波实际生成Boss" % stage)
		battle.clear_combatants(); battle.current_map_id = str(map_id); battle.wave = int(data.waves_to_clear); battle.stage_cleared = false; battle.spawn_wave()
		if battle.enemies.size() != 1 or battle.enemies[0].enemy_type != "boss" or battle.enemies[0]._name() != str(data.boss_name): failures.append("第%d关未生成唯一命名Boss" % stage)
	if seen.size() != 60:
		failures.append("全局关卡编号不完整")
	else:
		for stage in range(1, 61):
			if not seen.has(stage): failures.append("缺少第%d关" % stage)
	battle.clear_combatants()
	var curve40: float = battle.difficulty_multiplier("regular_health", 40)
	var curve41: float = battle.difficulty_multiplier("regular_health", 41)
	var curve60: float = battle.difficulty_multiplier("regular_health", 60)
	if not (curve40 < curve41 and curve41 < curve60 and curve60 < curve40 * 1.8): failures.append("41—60关成长曲线不连续或膨胀异常")

func _validate_new_exclusive_skills() -> void:
	var actor_ids := ["varian_wrynn","anduin_wrynn","thrall","arthas_menethil","illidan_stormrage","jaina_proudmoore","guo_jing","huang_rong","yang_guo","xiaolongnu","zhang_wuji","zhou_zhiruo","qiao_feng","duan_yu","linghu_chong","ren_yingying"]
	var skill_ids: Dictionary = {}
	for actor_id in actor_ids:
		battle.clear_combatants()
		var hero = battle.spawn_unit(actor_id, "heroes", Vector2(200, 220))
		var enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(260, 220))
		hero.target = enemy; hero.skill_timer = 0.0; hero.hp = hero.max_hp * 0.5
		if not hero.try_use_skill(): failures.append("专属主动未实际释放：%s" % actor_id)
		var active_id := str(hero.actor_data.get("skill", ""))
		if skill_ids.has(active_id): failures.append("新角色专属主动ID重复：%s" % active_id)
		skill_ids[active_id] = true
		var passive_id := str(hero.actor_data.get("passive_skill", ""))
		if not battle.passives_config.has(passive_id) or str(battle.passives_config[passive_id].get("effect", "")).is_empty(): failures.append("专属被动未配置实际效果：%s" % actor_id)
	battle.clear_combatants()

func _validate_general_skills() -> void:
	var jin_active := 0
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		if str(data.get("world", "")) == "金庸" and str(data.get("category", "")) == "active":
			jin_active += 1
			if str(data.get("damage_type", "none")) not in ["physical", "elemental"]: failures.append("金庸主动不是伤害技能：%s" % skill_id)
	if jin_active != 10: failures.append("金庸通用主动不是10个")
	battle.clear_combatants()
	var hero = battle.spawn_unit("guo_jing", "heroes", Vector2(200, 220))
	var enemy = battle.spawn_unit("jy_bladesman", "enemies", Vector2(260, 220))
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		if str(data.get("world", "")) != "金庸" or str(data.get("category", "")) != "active": continue
		enemy.hp = enemy.max_hp; hero.hp = hero.max_hp
		if not hero.try_use_general_skill(str(skill_id)) or enemy.hp >= enemy.max_hp: failures.append("金庸通用主动未造成真实伤害：%s" % skill_id)
	var death_coil: Dictionary = battle.general_skills_config.wow_death_coil
	hero.hp = hero.max_hp * 0.5; enemy.hp = enemy.max_hp
	var hp_before: float = hero.hp
	if not hero.try_use_general_skill("wow_death_coil") or hero.hp <= hp_before: failures.append("死亡缠绕未造成伤害并有限自愈")
	battle.clear_combatants()

func _validate_rifts_and_save_migration() -> void:
	if battle.adventure.config.rift.worlds.size() != 6: failures.append("大秘境世界不是6个")
	var p = battle.progression
	p.completed_stages = range(1, 61); p.ensure_world_layout(); p.ensure_adventure_layout()
	for world_id in ["three_kingdoms","pokemon","dragon","nsh","wow","jinyong"]:
		p.rift_progress[world_id].highest_clear = 59
		if not battle.adventure.rift_world_unlocked(world_id) or not battle.adventure.can_challenge_rift(world_id, 60) or battle.adventure.can_challenge_rift(world_id, 61): failures.append("秘境60/61层边界错误：%s" % world_id)
	var migrated = ProgressionManagerScript.new()
	var migration_path := "user://v09_legacy_migration_validation.json"
	if FileAccess.file_exists(migration_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	migrated.save_path = migration_path
	migrated.progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var legacy := {"version":"0.8","gold":777,"materials":{"jianghu_token":33},"roster":["liu_bei","zero"],"party":["liu_bei","zero","", ""],"completed_stages":range(1,41),"actor_levels":{"zero":18},"rift_progress":{"nsh":{"highest_clear":22,"selected_floor":22,"auto_climb":false,"first_clear_claimed":[1,2]}}}
	if not migrated.apply_payload(legacy) or migrated.gold != 777 or int(migrated.actor_levels.zero) != 18 or not migrated.can_enter_stage(41) or int(migrated.materials.azeroth_token) != 0 or not migrated.rift_progress.has("wow"): failures.append("V0.8存档迁移未保留旧数据或初始化新字段")
	elif not migrated.save_to_disk(): failures.append("迁移后的V0.9存档无法写入")
	var reloaded = ProgressionManagerScript.new(); reloaded.save_path = migration_path; reloaded.progression_config = migrated.progression_config
	if not reloaded.load_from_disk() or reloaded.gold != 777 or not reloaded.can_enter_stage(41) or int(reloaded.rift_progress.nsh.highest_clear) != 22: failures.append("迁移存档重启读取不一致")
	if FileAccess.file_exists(migration_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	migrated.free(); reloaded.free()

func _validate_boss_labels() -> void:
	battle.clear_combatants()
	var boss = battle.spawn_unit("wow_boss_lich_king", "enemies", Vector2.ZERO, {"name":"巫妖王·阿尔萨斯","enemy_type":"boss","boss_id":"stage_50"})
	if not boss.is_true_boss_unit() or boss.boss_display_name() != "巫妖王·阿尔萨斯": failures.append("真实Boss未显示实际中文名称")
	var normal = battle.spawn_unit("wow_ghoul", "enemies", Vector2.ZERO)
	if normal.is_true_boss_unit() or not normal.boss_display_name().is_empty(): failures.append("普通怪错误显示Boss名称")
	var hero = battle.spawn_unit("arthas_menethil", "heroes", Vector2.ZERO)
	if hero.is_true_boss_unit() or not hero.boss_display_name().is_empty(): failures.append("玩家英雄错误显示Boss标记")
