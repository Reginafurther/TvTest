extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const BattleUnitScript = preload("res://scripts/unit.gd")
const CombatStatsScript = preload("res://scripts/combat_stats.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_validate_aggregate_math(failures)
	_validate_real_damage_attribution(failures)
	_validate_summon_attribution(failures)
	if failures.is_empty():
		print("V10_SKILL_DAMAGE_STATS_VALIDATION_PASS actual_hp=true multihit=true dot=true summon_owner=true reset=true")
		quit(0)
		return
	for failure in failures: push_error("V10_SKILL_DAMAGE_STATS_VALIDATION_FAIL: " + failure)
	quit(1)

func _validate_aggregate_math(failures: Array[String]) -> void:
	var stats = CombatStatsScript.new(); stats.reset(0.0)
	stats.record_damage("zhou_yu", "dummy", 100.0, "skill", "red_cliff_flames")
	stats.record_damage("zhou_yu", "dummy", 70.0, "skill", "red_cliff_flames")
	stats.record_damage("zhou_yu", "dummy", 30.0, "effect", "red_cliff_flames:burn")
	stats.record_damage("zhou_yu", "dummy", 50.0, "basic", "basic")
	var row: Dictionary = stats.snapshot(10.0, ["zhou_yu"]).actors.zhou_yu
	if int(row.damage) != 250 or int(row.damage_sources.red_cliff_flames.damage) != 170: failures.append("skill totals did not aggregate")
	if int(row.damage_sources.red_cliff_flames.hits) != 2 or int(row.damage_sources.red_cliff_flames.average) != 85: failures.append("hit count or average is wrong")
	if not is_equal_approx(float(row.damage_sources["red_cliff_flames:burn"].percent), 12.0): failures.append("damage percentage is wrong")
	stats.reset(10.0)
	if not stats.actors.is_empty(): failures.append("reset did not clear skill details")

func _controller_fixture() -> Dictionary:
	var battle = BattleControllerScript.new(); root.add_child(battle)
	battle.combat_stats = CombatStatsScript.new(); battle.combat_stats.reset()
	battle.worlds_config = {"maps":{}}; battle.current_map_id = ""; battle.suppress_combat_visuals = true
	var source = BattleUnitScript.new(); battle.add_child(source)
	var target = BattleUnitScript.new(); battle.add_child(target)
	source.battle = battle; source.actor_id = "zhou_yu"; source.faction = "heroes"; source.actor_data = {"name":"周瑜", "skill":"red_cliff_flames", "basic_damage_type":"elemental"}; source.attack = 100.0; source.max_hp = 1000.0; source.hp = 1000.0
	target.battle = battle; target.actor_id = "dummy"; target.faction = "enemies"; target.actor_data = {"name":"木桩"}; target.max_hp = 10000.0; target.hp = 10000.0; target.defense = 100.0
	battle.heroes = [source]; battle.enemies = [target]
	return {"battle":battle, "source":source, "target":target}

func _validate_real_damage_attribution(failures: Array[String]) -> void:
	var fixture := _controller_fixture(); var battle = fixture.battle; var source = fixture.source; var target = fixture.target
	var result: Dictionary = target.take_damage(200.0, source, false, {"kind":"skill", "skill_id":"red_cliff_flames", "allow_triggers":false})
	var snapshot: Dictionary = source.combat_source_snapshot(source, "elemental", "red_cliff_flames")
	target.take_damage(100.0, source, false, {"kind":"effect", "burn":true, "source_snapshot":snapshot, "allow_triggers":false})
	var row: Dictionary = battle.combat_stats.snapshot(5.0, ["zhou_yu"]).actors.zhou_yu
	if int(row.damage_sources.red_cliff_flames.damage) != int(result.hp_damage): failures.append("stats used configured damage instead of actual HP loss")
	if not row.damage_sources.has("red_cliff_flames:burn"): failures.append("burn tick lost its originating skill")
	battle.free()

func _validate_summon_attribution(failures: Array[String]) -> void:
	var fixture := _controller_fixture(); var battle = fixture.battle; var summon = fixture.source; var target = fixture.target
	summon.actor_id = "medicine_avatar"; summon.actor_data = {"name":"药人", "skill":"enemy_strike", "basic_damage_type":"elemental"}; summon.is_summon = true; summon.summon_owner_id = "nine_spirits"
	target.take_damage(80.0, summon, false, {"kind":"basic", "allow_triggers":false})
	var snapshot: Dictionary = battle.combat_stats.snapshot(5.0, ["nine_spirits"])
	if not snapshot.actors.has("nine_spirits") or not snapshot.actors.nine_spirits.damage_sources.has("summon:medicine_avatar"):
		failures.append("summon damage was not attributed to its owner")
	# Independent summon events merge into the same owner/source row.
	target.take_damage(80.0, summon, false, {"kind":"effect", "allow_triggers":false})
	snapshot = battle.combat_stats.snapshot(5.0, ["nine_spirits"])
	if not snapshot.actors.nine_spirits.damage_sources.has("summon:medicine_avatar"): failures.append("summon source detail is missing")
	battle.free()
