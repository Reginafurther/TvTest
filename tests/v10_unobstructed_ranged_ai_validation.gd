extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleMapScript = preload("res://scripts/battle_map.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")

class SkillProgression extends RefCounted:
	var skill_priorities := {}

class FakeBattle extends Node:
	var heroes: Array = []
	var enemies: Array = []
	var progression := SkillProgression.new()
	var general_skills_config := {}
	var active_rift_context := {}
	var suppress_combat_visuals := true
	var is_paused := false
	func select_combat_target(seeker):
		var pool: Array = enemies if seeker.faction == "heroes" else heroes
		for candidate in pool:
			if is_instance_valid(candidate) and not candidate.dead: return candidate
		return null
	func strategy_allows(_unit) -> bool: return false
	func enemies_near(center: Vector2, source_faction: String, radius: float, limit: int) -> Array:
		var pool: Array = enemies if source_faction == "heroes" else heroes
		var result: Array = []
		for candidate in pool:
			if is_instance_valid(candidate) and not candidate.dead and candidate.position.distance_to(center) <= radius:
				result.append(candidate)
				if result.size() >= limit: break
		return result
	func record_damage_resolution(_source, _target, _result: Dictionary, _context: Dictionary) -> void: pass
	func on_damage(_source, _target, _amount: float, _context: Dictionary) -> void: pass
	func on_heal(_source, _amount: float, _snapshot: Dictionary = {}) -> void: pass
	func note_passive(_actor_id: String, _passive_id: String) -> void: pass
	func spawn_tracer(_from: Vector2, _to: Vector2, _color: Color) -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await physics_frame
	var failures: Array[String] = []
	_validate_unobstructed_map(failures)
	_validate_ranged_attack_priority(failures)
	_validate_ranged_pursuit(failures)
	_validate_rally_interrupt(failures)
	if failures.is_empty():
		print("V10_UNOBSTRUCTED_RANGED_AI_VALIDATION_PASS obstacles=0 direct_path=true ranged_attack=true pursuit=true rally_interrupt=true")
		quit(0)
		return
	for failure in failures: push_error("V10_UNOBSTRUCTED_RANGED_AI_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_unobstructed_map(failures: Array[String]) -> void:
	var controller = BattleControllerScript.new()
	controller.battle_map = BattleMapScript.new()
	if not controller.battle_map.obstacles.is_empty(): failures.append("fixed obstacles still exist")
	var path := controller.find_path(Vector2(100, 100), Vector2(900, 400))
	if path.size() != 1 or path[0] != Vector2(900, 400): failures.append("movement path is not direct")
	if controller.point_blocked(Vector2(500, 250)): failures.append("arena centre is incorrectly blocked")
	if not controller.point_blocked(Vector2(-5, 250)): failures.append("arena boundary protection was removed")
	controller.battle_map.free()
	controller.free()

func _fixture() -> Dictionary:
	var battle := FakeBattle.new(); root.add_child(battle)
	var ranged = BattleUnitScript.new(); battle.add_child(ranged)
	var enemy = BattleUnitScript.new(); battle.add_child(enemy)
	ranged.battle = battle; ranged.faction = "heroes"; ranged.actor_id = "zhou_yu"
	ranged.actor_data = {"name":"周瑜", "combat_style":"ranged", "combat_role":"ranged_dps", "minimum_safe_distance":120.0, "basic_damage_type":"elemental"}
	ranged.attack = 100.0; ranged.attack_range = 220.0; ranged.attack_interval = 1.0; ranged.max_hp = 1000.0; ranged.hp = 1000.0; ranged.skill_timer = 99.0; ranged.target_refresh_timer = 99.0
	enemy.battle = battle; enemy.faction = "enemies"; enemy.actor_id = "dummy"; enemy.actor_data = {"name":"木桩"}; enemy.max_hp = 10000.0; enemy.hp = 10000.0; enemy.defense = 0.0
	battle.heroes = [ranged]; battle.enemies = [enemy]; battle.progression.skill_priorities[ranged.actor_id] = ["exclusive"]
	ranged.target = enemy
	return {"battle":battle, "ranged":ranged, "enemy":enemy}

func _dispose(fixture: Dictionary) -> void:
	fixture.battle.free()

func _validate_ranged_attack_priority(failures: Array[String]) -> void:
	var fixture := _fixture(); var ranged = fixture.ranged; var enemy = fixture.enemy
	ranged.position = Vector2(100, 100); enemy.position = Vector2(180, 100)
	ranged._physics_process(0.1)
	if enemy.hp >= enemy.max_hp or ranged.current_action != "basic_attack": failures.append("ranged hero retreated instead of attacking an in-range enemy")
	_dispose(fixture)

func _validate_ranged_pursuit(failures: Array[String]) -> void:
	var fixture := _fixture(); var ranged = fixture.ranged; var enemy = fixture.enemy
	ranged.position = Vector2(100, 100); enemy.position = Vector2(600, 100); ranged.attack_timer = 1.0
	ranged._physics_process(0.1)
	if ranged.position.x <= 100.0 or ranged.current_action != "seek_firing_position": failures.append("ranged hero did not pursue an out-of-range enemy")
	_dispose(fixture)

func _validate_rally_interrupt(failures: Array[String]) -> void:
	var fixture := _fixture(); var ranged = fixture.ranged; var enemy = fixture.enemy
	ranged.position = Vector2(100, 100); enemy.position = Vector2(190, 100)
	ranged.set_rally(Vector2(900, 400)); ranged._physics_process(0.1)
	if ranged.has_rally or enemy.hp >= enemy.max_hp: failures.append("rally state blocked combat against a nearby enemy")
	_dispose(fixture)
