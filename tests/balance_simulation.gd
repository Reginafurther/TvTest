extends SceneTree

const TRIALS := 120
const SCENARIOS := [
	{"id":"A", "label":"Lv7普通装/无通用技能", "level":7, "party":["zhao_yun","zhang_fei","dian_wei","pikachu"], "gear":1.0, "skills":0, "extra_heal":0.0, "survival":1.0},
	{"id":"B", "label":"Lv7普通装/刘备治疗", "level":7, "party":["zhao_yun","zhang_fei","pikachu","liu_bei"], "gear":1.0, "skills":0, "extra_heal":0.0, "survival":1.0},
	{"id":"C", "label":"Lv10普通装/基础技能", "level":10, "party":["zhao_yun","zhang_fei","pikachu","liu_bei"], "gear":1.0, "skills":1, "extra_heal":0.0, "survival":1.0},
	{"id":"D", "label":"Lv10良装/完整技能", "level":10, "party":["zhao_yun","zhang_fei","pikachu","liu_bei"], "gear":1.7, "skills":2, "extra_heal":0.0, "survival":2.0},
	{"id":"E", "label":"Lv15均衡队", "level":15, "party":["zhao_yun","zhang_fei","zhuge_liang","liu_bei"], "gear":1.5, "skills":2, "extra_heal":0.0, "survival":3.0},
	{"id":"F", "label":"Lv20成型Build", "level":20, "party":["zhao_yun","zhang_fei","mewtwo","liu_bei"], "gear":2.2, "skills":3, "extra_heal":0.0, "survival":2.0},
	{"id":"G", "label":"Lv12无治疗高输出", "level":12, "party":["zhao_yun","dian_wei","zhuge_liang","pikachu"], "gear":1.4, "skills":2, "extra_heal":0.0, "survival":2.0},
	{"id":"H", "label":"Lv12多通用治疗", "level":12, "party":["zhao_yun","zhang_fei","zhuge_liang","liu_bei"], "gear":1.3, "skills":1, "extra_heal":25.0, "survival":3.0}
]

var actors: Dictionary
var maps: Dictionary
var difficulty: Dictionary
var rng := RandomNumberGenerator.new()

func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	actors = load_json("res://data/actors.json")
	maps = load_json("res://data/worlds.json").get("maps", {})
	difficulty = load_json("res://data/progression.json").get("combat_difficulty", {})
	rng.seed = 20261014
	var failures: Array[String] = []
	var results: Dictionary = {}
	for scenario in SCENARIOS:
		var first_block := 21
		var scenario_rows: Dictionary = {}
		for stage in range(1, 21):
			var base: Dictionary = encounter_estimate(scenario, stage)
			var clears := 0
			var total_time := 0.0
			var total_casualties := 0.0
			for _trial in range(TRIALS):
				var time := float(base.time) / rng.randf_range(0.88, 1.12)
				var survival_margin := float(base.survival) * rng.randf_range(0.82, 1.16)
				var success := time <= 180.0 and survival_margin >= 0.90
				if success: clears += 1
				total_time += minf(time, 180.0)
				total_casualties += clampf((1.25 - survival_margin) * 2.2, 0.0, 4.0)
			var row := {"pass_rate":float(clears) / TRIALS, "avg_time":total_time / TRIALS, "boss_time":float(base.boss_time), "casualties":total_casualties / TRIALS, "dps":float(base.dps), "healing":float(base.healing), "gear":float(base.gear_contribution), "skill":float(base.skill_contribution)}
			scenario_rows[stage] = row
			if first_block == 21 and float(row.pass_rate) < 0.50: first_block = stage
		results[str(scenario.id)] = scenario_rows
		print("BALANCE_SCENARIO %s first_block=%s stage10=%.2f stage15=%.2f stage18=%.2f stage20=%.2f label=%s" % [scenario.id, "none" if first_block == 21 else str(first_block), scenario_rows[10].pass_rate, scenario_rows[15].pass_rate, scenario_rows[18].pass_rate, scenario_rows[20].pass_rate, scenario.label])
	if float(results.A[18].pass_rate) > 0.15 or float(results.B[18].pass_rate) > 0.25:
		failures.append("Lv7普通装备阵容仍可轻松通过第18关")
	if float(results.D[10].pass_rate) < 0.70:
		failures.append("Lv10良装完整技能无法稳定完成第一世界")
	if float(results.F[20].pass_rate) < 0.70:
		failures.append("Lv20成型Build无法稳定完成第20关")
	if float(results.H[20].pass_rate) > 0.50:
		failures.append("多治疗组合在后期形成无成长需求的无限生存")
	if failures.is_empty():
		print("V061_BALANCE_MATRIX_PASS scenarios=8 stages=20 trials_per_cell=%d lv7_stage18_blocked=true lv10_world1_viable=true lv20_stage20_viable=true multi_heal_not_immortal=true" % TRIALS)
	else:
		for failure in failures: push_error("V061_BALANCE_MATRIX_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func curve_multiplier(id: String, stage: int) -> float:
	var curve: Dictionary = difficulty.get(id, {})
	var step := float(stage - 1)
	return 1.0 + step * float(curve.get("linear", 0.0)) + step * step * float(curve.get("quadratic", 0.0))

func encounter_estimate(scenario: Dictionary, stage: int) -> Dictionary:
	var dps := 0.0
	var healing := float(scenario.extra_heal)
	var ehp := 0.0
	var gear_contribution := 0.0
	var skill_contribution := 0.0
	for actor_id in scenario.party:
		var actor: Dictionary = actors[actor_id]
		var level := int(scenario.level)
		var gear := float(scenario.gear)
		var base_attack := float(actor.attack) * (1.0 + (level - 1) * 0.06)
		var attack := base_attack + level * 2.5 * gear
		var hp := float(actor.max_hp) * (1.0 + (level - 1) * 0.08) + level * 18.0 * gear
		var defense := float(actor.defense) * (1.0 + (level - 1) * 0.05) + level * 1.1 * gear
		gear_contribution += attack - base_attack
		ehp += hp * (1.0 + defense * 0.012)
		if actor.get("basic_action", "damage") == "heal":
			healing += attack * 0.40 / float(actor.attack_interval)
			if int(scenario.skills) > 0: healing += attack * 1.35 / 6.5
		else:
			var basic_dps := attack / float(actor.attack_interval)
			dps += basic_dps
			if int(scenario.skills) > 0:
				var exclusive := attack * 1.4 / 6.0
				dps += exclusive; skill_contribution += exclusive
			if int(scenario.skills) > 1:
				var general := attack * 0.8 / 8.0 * int(scenario.skills)
				dps += general; skill_contribution += general
	var map_data: Dictionary
	for value in maps.values():
		if int(value.global_stage) == stage: map_data = value; break
	var pool: Array = map_data.enemy_pool
	var normal_hp := 0.0
	var normal_dps := 0.0
	for enemy_id in pool:
		normal_hp += float(actors[enemy_id].max_hp)
		normal_dps += float(actors[enemy_id].attack) / float(actors[enemy_id].attack_interval)
	normal_hp /= pool.size(); normal_dps /= pool.size()
	var regular_hp := normal_hp * curve_multiplier("regular_health", stage) * (4.0 + (4.0 + 1.75) * 1.12)
	var boss: Dictionary = actors[str(map_data.main_boss)]
	var boss_hp: float
	var boss_attack: float
	var boss_defense: float
	if str(map_data.main_boss).begins_with("stage_guardian"):
		boss_hp = float(boss.max_hp) * curve_multiplier("guardian_health", stage)
		boss_attack = float(boss.attack) / float(boss.attack_interval) * curve_multiplier("guardian_attack", stage)
		boss_defense = float(boss.defense) * curve_multiplier("guardian_defense", stage)
	else:
		var final_scale: Dictionary = difficulty.final_boss[str(stage)]
		boss_hp = float(boss.max_hp) * float(final_scale.health)
		boss_attack = float(boss.attack) / float(boss.attack_interval) * float(final_scale.attack)
		boss_defense = float(boss.defense) * float(final_scale.defense)
	var defense_factor := maxf(0.25, 1.0 - boss_defense * 0.55 / maxf(1.0, dps * 0.9))
	var boss_time := boss_hp / maxf(1.0, dps * defense_factor)
	var total_time := regular_hp / maxf(1.0, dps * 1.15) + boss_time + 10.0
	var incoming := normal_dps * curve_multiplier("regular_attack", stage) * 2.5 + boss_attack
	var sustainable := (ehp + healing * total_time * 0.65) * float(scenario.survival)
	return {"time":total_time, "boss_time":boss_time, "survival":sustainable / maxf(1.0, incoming * total_time), "dps":dps, "healing":healing, "gear_contribution":gear_contribution, "skill_contribution":skill_contribution}
