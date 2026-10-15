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
	_validate_counts_and_ids()
	_validate_progression_and_rifts()
	_validate_stage_templates()
	_validate_exclusive_runtime()
	_validate_general_runtime()
	_validate_v09_migration()
	battle.clear_combatants()
	if FileAccess.file_exists(battle.progression.save_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(battle.progression.save_path))
	battle.queue_free()
	await process_frame
	if failures.is_empty():
		print("V10_EIGHT_WORLDS_VALIDATION_PASS worlds=8 stages=80 playable=72 new_exclusive=20 new_general=40 rifts=8 level_cap=80 migration=true")
		quit(0)
		return
	for failure in failures: push_error("V10_EIGHT_WORLDS_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_counts_and_ids() -> void:
	var playable: Array[String] = []
	var world_counts := {"秦时明月":0, "火影忍者":0}
	for actor_id in battle.actors:
		var actor: Dictionary = battle.actors[actor_id]
		if actor.has("enemy_type") or not actor.has("passive_skill"): continue
		playable.append(str(actor_id))
		var world := str(actor.get("world", ""))
		if world in world_counts: world_counts[world] += 1
	if playable.size() != 72: failures.append("可玩角色不是72名：%d" % playable.size())
	if battle.progression.HERO_IDS.size() != 72 or battle.inventory.HERO_IDS.size() != 72: failures.append("成长或装备角色ID没有扩展到72名")
	if world_counts != {"秦时明月":10, "火影忍者":10}: failures.append("两个新世界角色数量错误：%s" % world_counts)
	if battle.worlds_config.maps.size() != 80: failures.append("主线地图不是80张：%d" % battle.worlds_config.maps.size())
	var skill_counts := {"秦时明月_active":0,"秦时明月_passive":0,"火影忍者_active":0,"火影忍者_passive":0}
	for skill_id in battle.general_skills_config:
		var data: Dictionary = battle.general_skills_config[skill_id]
		var key := str(data.get("world", "")) + "_" + str(data.get("category", ""))
		if key in skill_counts: skill_counts[key] += 1
	if skill_counts != {"秦时明月_active":10,"秦时明月_passive":10,"火影忍者_active":10,"火影忍者_passive":10}: failures.append("新世界通用技能数量错误：%s" % skill_counts)

func _validate_progression_and_rifts() -> void:
	var p = battle.progression
	p.completed_stages = range(1, 60); p.ensure_world_layout()
	if p.world_unlocked("秦时明月") or p.can_enter_stage(61): failures.append("未通关60关即可进入秦时明月")
	p.completed_stages = range(1, 61); p.ensure_world_layout()
	if not p.world_unlocked("秦时明月") or p.world_unlocked("火影忍者") or not p.can_enter_stage(61): failures.append("第60关世界解锁边界错误")
	p.completed_stages = range(1, 71); p.ensure_world_layout()
	if not p.world_unlocked("火影忍者") or not p.can_enter_stage(71): failures.append("第70关未开放火影忍者")
	p.completed_stages = range(1, 61); p.ensure_world_layout()
	for stage in range(61, 81):
		if not p.complete_stage(stage): failures.append("第%d关无法按顺序记录通关" % stage)
	p.ensure_adventure_layout()
	if p.can_enter_stage(81) or p.highest_unlocked_stage() != 80 or p.main_stage_limit() != 80: failures.append("第80关终点防线错误")
	if p.actor_level_cap() != 80: failures.append("角色动态等级上限不是80")
	if not battle.adventure.achievement_ready("clear_naruto"): failures.append("80关通关成就未达成")
	if battle.adventure.config.rift.worlds.size() != 8: failures.append("大秘境世界不是8个")
	for world_id in ["three_kingdoms","pokemon","dragon","nsh","wow","jinyong","qin","naruto"]:
		p.rift_progress[world_id].highest_clear = 79
		if not battle.adventure.rift_world_unlocked(world_id) or not battle.adventure.can_challenge_rift(world_id, 80) or battle.adventure.can_challenge_rift(world_id, 81): failures.append("秘境80/81层边界错误：%s" % world_id)

func _validate_stage_templates() -> void:
	var seen: Dictionary = {}
	for map_id in battle.worlds_config.maps:
		var data: Dictionary = battle.worlds_config.maps[map_id]
		var stage := int(data.get("global_stage", 0)); seen[stage] = true
		var pool: Array[String] = battle.valid_mainline_enemy_pool(data)
		if pool.size() != data.get("enemy_pool", []).size(): failures.append("第%d关普通怪池含Boss或无效模板" % stage)
		for enemy_id in pool:
			var enemy: Dictionary = battle.actors.get(enemy_id, {})
			if str(enemy.get("enemy_type", "normal")) == "boss" or enemy.has("boss_id"): failures.append("第%d关普通怪带Boss身份" % stage)
		if stage >= 61:
			var boss: Dictionary = battle.actors.get(str(data.get("main_boss", "")), {})
			if str(boss.get("enemy_type", "")) != "boss" or str(boss.get("name", "")) != str(data.get("boss_name", "")): failures.append("第%d关Boss模板或中文名错误" % stage)
	for stage in range(1, 81):
		if not seen.has(stage): failures.append("缺少全局第%d关" % stage)
	if not battle.stage_id_for_number(81).is_empty(): failures.append("错误生成了第81关")

func _validate_exclusive_runtime() -> void:
	var actor_ids := ["qin_gai_nie","qin_wei_zhuang","qin_jing_tianming","qin_xiang_shaoyu","qin_gao_jianli","qin_xue_nv","qin_duanmu_rong","qin_shaosiming","qin_xiaomeng","qin_zhang_liang","naruto_uzumaki","naruto_sasuke","naruto_sakura","naruto_kakashi","naruto_itachi","naruto_shikamaru","naruto_hinata","naruto_gaara","naruto_jiraiya","naruto_tsunade"]
	var active_ids: Dictionary = {}; var passive_ids: Dictionary = {}
	for actor_id in actor_ids:
		battle.clear_combatants()
		var hero = battle.spawn_unit(actor_id, "heroes", Vector2(220, 220))
		var ally = battle.spawn_unit("liu_bei", "heroes", Vector2(245, 235)); ally.hp = ally.max_hp * 0.35
		var enemy = battle.spawn_unit("naruto_rogue_ninja", "enemies", Vector2(280, 220))
		hero.target = enemy; hero.hp = hero.max_hp * 0.5; hero.skill_timer = 0.0
		if actor_id == "naruto_jiraiya":
			hero.hp = hero.max_hp * 0.8; battle.is_paused = false; hero._physics_process(0.1); battle.is_paused = true
			if hero.metamorphosis_time <= 0.0 or hero.metamorphosis_cooldown < 17.0: failures.append("自来也仙人模式没有持续时间、触发条件与冷却")
		if not hero.try_use_skill(): failures.append("专属主动未真实释放：%s" % actor_id)
		var active_id := str(hero.actor_data.get("skill", "")); var passive_id := str(hero.actor_data.get("passive_skill", ""))
		if active_ids.has(active_id): failures.append("专属主动ID重复：%s" % active_id)
		if passive_ids.has(passive_id): failures.append("专属被动ID重复：%s" % passive_id)
		active_ids[active_id] = true; passive_ids[passive_id] = true
		if not battle.passives_config.has(passive_id) or str(battle.passives_config[passive_id].get("effect", "")).is_empty(): failures.append("专属被动没有真实效果：%s" % actor_id)

func _validate_general_runtime() -> void:
	for world in ["秦时明月", "火影忍者"]:
		for skill_id in battle.general_skills_config:
			var data: Dictionary = battle.general_skills_config[skill_id]
			if str(data.get("world", "")) != world or str(data.get("category", "")) != "active": continue
			battle.clear_combatants()
			var hero = battle.spawn_unit("naruto_kakashi", "heroes", Vector2(220, 220))
			var ally = battle.spawn_unit("liu_bei", "heroes", Vector2(240, 230)); ally.hp = ally.max_hp * 0.35
			var enemy = battle.spawn_unit("naruto_rogue_ninja", "enemies", Vector2(280, 220))
			hero.target = enemy; hero.hp = hero.max_hp * 0.5
			if not hero.try_use_general_skill(str(skill_id)): failures.append("通用主动未真实生效：%s" % skill_id)
	battle.clear_combatants()
	var clone_owner = battle.spawn_unit("naruto_uzumaki", "heroes", Vector2(220, 220))
	var clone_enemy = battle.spawn_unit("naruto_rogue_ninja", "enemies", Vector2(280, 220)); clone_owner.target = clone_enemy
	if not clone_owner.try_use_general_skill("naruto_shadow_clone"): failures.append("影分身未能召唤")
	var clones: Array = battle.heroes.filter(func(member): return member.is_summon and member.summon_owner_id == "naruto_uzumaki")
	if clones.size() != 1 or clone_owner.try_use_general_skill("naruto_shadow_clone"): failures.append("影分身数量限制或防递归失效")

func _validate_v09_migration() -> void:
	var migrated = ProgressionManagerScript.new()
	var migration_path := "user://v10_legacy_migration_validation.json"
	if FileAccess.file_exists(migration_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	migrated.save_path = migration_path
	migrated.progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var legacy := {"version":"0.9","gold":888,"materials":{"wuxia_token":44},"roster":["liu_bei","guo_jing"],"party":["liu_bei","guo_jing","", ""],"completed_stages":range(1,61),"actor_levels":{"guo_jing":41},"rift_progress":{"jinyong":{"highest_clear":36,"selected_floor":36,"auto_climb":false,"first_clear_claimed":[1,2]}}}
	if not migrated.apply_payload(legacy): failures.append("V0.9存档不能迁移")
	elif migrated.gold != 888 or int(migrated.materials.wuxia_token) != 44 or int(migrated.materials.qin_moon_token) != 0 or int(migrated.actor_levels.guo_jing) != 41: failures.append("V0.9迁移丢失角色、等级或材料")
	elif not migrated.can_enter_stage(61) or migrated.can_enter_stage(62) or not migrated.rift_progress.has("qin") or not migrated.rift_progress.has("naruto"): failures.append("V0.9迁移未初始化新世界边界")
	elif not migrated.save_to_disk(): failures.append("迁移后的V1.0存档无法写入")
	var reloaded = ProgressionManagerScript.new(); reloaded.save_path = migration_path; reloaded.progression_config = migrated.progression_config
	if not reloaded.load_from_disk() or reloaded.gold != 888 or int(reloaded.rift_progress.jinyong.highest_clear) != 36 or reloaded.completed_stages.size() != 60: failures.append("V1.0迁移存档重启读取不一致")
	if FileAccess.file_exists(migration_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	migrated.free(); reloaded.free()
