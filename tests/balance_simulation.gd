extends SceneTree

const PARTY := ["zhao_yun", "liu_bei", "zhang_fei", "zhuge_liang"]
const TRIALS := 400

func load_json(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _init() -> void:
	var actors: Dictionary = load_json("res://data/actors.json")
	var skills: Dictionary = load_json("res://data/skills.json")
	var worlds: Dictionary = load_json("res://data/worlds.json").get("maps", {})
	var maps: Array = worlds.keys()
	maps.sort_custom(func(a, b): return int(worlds[a].global_stage) < int(worlds[b].global_stage))
	var rng := RandomNumberGenerator.new(); rng.seed = 20261014
	var failures: Array[String] = []
	var previous_boss_hp := 0.0
	print("BALANCE_TABLE stage avg_seconds p10 p90 survival boss_hp party_dps")
	for map_id in maps:
		var map_data: Dictionary = worlds[map_id]
		var stage: int = int(map_data.global_stage)
		var party_dps: float = estimated_party_dps(stage, actors, skills)
		var healing: float = estimated_healing(stage, actors, skills)
		var party_ehp: float = estimated_party_ehp(stage, actors)
		var regular_hp: float = regular_wave_hp(stage, actors, map_data)
		var boss_stats: Dictionary = stage_boss_stats(stage, actors, map_data)
		var boss_hp: float = float(boss_stats.hp)
		var boss_defense: float = float(boss_stats.defense)
		var attack_factor: float = maxf(0.42, 1.0 - boss_defense * 0.55 / maxf(1.0, party_dps * 0.22))
		var samples: Array[float] = []
		var survival_samples: Array[float] = []
		for _trial in range(TRIALS):
			var output_roll: float = rng.randf_range(0.88, 1.12)
			var mechanic_delay: float = rng.randf_range(1.5, 4.5) + stage * 0.08
			var seconds: float = regular_hp / (party_dps * 1.28 * output_roll) + boss_hp / (party_dps * attack_factor * output_roll) + 4.4 + mechanic_delay
			var incoming_dps: float = estimated_incoming_dps(stage, actors, map_data, boss_stats) * rng.randf_range(0.88, 1.14)
			var sustainable: float = party_ehp + healing * seconds * 0.58
			var pressure: float = incoming_dps * seconds
			samples.append(seconds)
			survival_samples.append(sustainable / maxf(1.0, pressure))
		samples.sort(); survival_samples.sort()
		var average: float = 0.0
		for value in samples: average += value
		average /= samples.size()
		var survival: float = survival_samples[int(TRIALS * 0.1)]
		print("BALANCE_STAGE %02d %.1f %.1f %.1f %.2f %.0f %.1f" % [stage, average, samples[int(TRIALS * 0.1)], samples[int(TRIALS * 0.9)], survival, boss_hp, party_dps])
		if average < 12.0: failures.append("第%d关平均通关过快 %.1fs" % [stage, average])
		if average > 150.0: failures.append("第%d关平均通关过慢 %.1fs" % [stage, average])
		if survival < 0.9: failures.append("第%d关典型队伍生存裕量不足 %.2f" % [stage, survival])
		if boss_hp <= previous_boss_hp: failures.append("第%d关Boss生命未递增" % stage)
		previous_boss_hp = boss_hp
	if failures.is_empty():
		print("V061_BALANCE_TEST_PASS stages=20 trials_per_stage=%d curve=progressive avg_clear=12-150s survival_p10>=0.90" % TRIALS)
	else:
		for failure in failures: push_error("V061_BALANCE_TEST_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func estimated_party_dps(stage: int, actors: Dictionary, skills: Dictionary) -> float:
	var total := 0.0
	for actor_id in PARTY:
		var actor: Dictionary = actors[actor_id]
		var attack: float = float(actor.attack) * (1.0 + (stage - 1) * 0.06) + 8.0 + stage * 3.0
		if actor.get("basic_action", "damage") != "heal": total += attack / float(actor.attack_interval)
		var skill: Dictionary = skills[actor.skill]
		if skill.type in ["damage", "area_damage", "chain"]: total += attack * float(skill.power) / float(skill.cooldown)
	return total

func estimated_healing(stage: int, actors: Dictionary, skills: Dictionary) -> float:
	var actor: Dictionary = actors.liu_bei
	var attack: float = float(actor.attack) * (1.0 + (stage - 1) * 0.06) + 8.0 + stage * 3.0
	var skill: Dictionary = skills[actor.skill]
	return attack * 0.72 / float(actor.attack_interval) + attack * float(skill.power) / float(skill.cooldown)

func estimated_party_ehp(stage: int, actors: Dictionary) -> float:
	var total := 0.0
	for actor_id in PARTY:
		var actor: Dictionary = actors[actor_id]
		var hp: float = float(actor.max_hp) * (1.0 + (stage - 1) * 0.08) + 35.0 * stage
		var defense: float = float(actor.defense) * (1.0 + (stage - 1) * 0.05) + 2.2 * stage
		total += hp * (1.0 + defense * 0.012)
	return total

func regular_wave_hp(stage: int, actors: Dictionary, map_data: Dictionary) -> float:
	var pool: Array = map_data.enemy_pool
	var base_hp: float = 0.0
	for actor_id in pool: base_hp += float(actors[actor_id].max_hp)
	base_hp /= pool.size()
	var stage_scale: float = 1.0 + (stage - 1) * 0.18
	# Wave 1 has four normals; wave 2 has four normals and one 1.75x elite.
	return base_hp * stage_scale * (4.0 + (4.0 + 1.75) * 1.12)

func stage_boss_stats(stage: int, actors: Dictionary, map_data: Dictionary) -> Dictionary:
	var actor: Dictionary = actors[str(map_data.main_boss)]
	if str(map_data.main_boss).begins_with("stage_guardian"):
		return {"hp":float(actor.max_hp) * (1.0 + stage * 0.35), "attack":float(actor.attack) * (1.0 + stage * 0.075), "defense":float(actor.defense) * (1.0 + stage * 0.055), "interval":float(actor.attack_interval)}
	return {"hp":float(actor.max_hp), "attack":float(actor.attack), "defense":float(actor.defense), "interval":float(actor.attack_interval)}

func estimated_incoming_dps(stage: int, actors: Dictionary, map_data: Dictionary, boss: Dictionary) -> float:
	var pool: Array = map_data.enemy_pool
	var regular_attack: float = 0.0
	var regular_interval: float = 0.0
	for actor_id in pool:
		regular_attack += float(actors[actor_id].attack)
		regular_interval += float(actors[actor_id].attack_interval)
	regular_attack = regular_attack / pool.size() * (1.0 + (stage - 1) * 0.11)
	regular_interval /= pool.size()
	var raw: float = regular_attack / regular_interval * 2.2 + float(boss.attack) / float(boss.interval)
	var tank: Dictionary = actors.zhang_fei
	var tank_defense: float = float(tank.defense) * (1.0 + (stage - 1) * 0.05) + 2.2 * stage
	return raw * maxf(0.36, 1.0 - tank_defense * 0.009)
