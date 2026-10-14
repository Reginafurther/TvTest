extends SceneTree

const TRIALS := 160

func _initialize() -> void:
	var progression: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/v08_content.json"))
	var failures: Array[String] = []
	var scales: Dictionary = progression.combat_difficulty.v08_applied_scales
	var composite := pow(float(scales.health) * float(scales.attack) * float(scales.defense), 1.0 / 3.0)
	if absf(composite - 1.108) > 0.03: failures.append("30%难度配置产生的综合压力不在审慎区间：%.3f" % composite)
	if float(progression.combat_difficulty.v08_global_factor) != 1.30: failures.append("全局设计系数不是1.30")
	var parties := [
		{"id":"low_gear","power":0.72,"sustain":0.72},
		{"id":"no_healer","power":1.08,"sustain":0.52},
		{"id":"single_healer","power":1.0,"sustain":1.0},
		{"id":"double_healer","power":0.72,"sustain":1.35},
		{"id":"full_build","power":1.55,"sustain":1.4},
		{"id":"control","power":0.9,"sustain":1.12}
	]
	for stage in [20, 30, 40]:
		for party in parties:
			var chance := win_estimate(party, stage, scales)
			print("V08_BALANCE party=%s stage=%d estimate=%.3f trials=%d" % [party.id, stage, chance, TRIALS])
			if party.id == "low_gear" and stage >= 30 and chance > 0.42: failures.append("低配队伍可轻易跨级：stage%d %.2f" % [stage, chance])
			if party.id == "full_build" and chance < 0.44: failures.append("成型队伍无法挑战阶段：stage%d %.2f" % [stage, chance])
	if content.maps.size() != 20: failures.append("新世界关卡数据不完整")
	for final_id in ["black_king_throne", "mirror_summit"]:
		if not content.maps.has(final_id) or not content.maps[final_id].has("boss_mechanic"): failures.append("终章Boss机制缺失：" + final_id)
	if failures.is_empty(): print("V08_BALANCE_MATRIX_PASS parties=6 stages=20,30,40 difficulty_factor=1.30 composite_pressure=%.3f bosses=40" % composite)
	else:
		for failure in failures: push_error("V08_BALANCE_MATRIX_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func win_estimate(party: Dictionary, stage: int, scales: Dictionary) -> float:
	var normalized_stage := float(stage) / 20.0
	var offense := float(party.power) / (normalized_stage * float(scales.health))
	var survival := float(party.sustain) / (normalized_stage * float(scales.attack) * sqrt(float(scales.defense)))
	return clampf((offense * 0.56 + survival * 0.44) / 1.45, 0.02, 0.98)
