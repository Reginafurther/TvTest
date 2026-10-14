extends SceneTree

const TRIALS := 160
const PARTIES := [
	{"id":"classic","label":"经典坦克治疗","members":["zhao_yun","zhang_fei","liu_bei","pikachu"],"level":10,"gear":1.35},
	{"id":"break","label":"破甲斩杀队","members":["guan_yu","huang_zhong","lucario","liu_bei"],"level":15,"gear":1.55},
	{"id":"burn","label":"双火持续队","members":["zhou_yu","charmander","bulbasaur","squirtle"],"level":15,"gear":1.50},
	{"id":"control","label":"控制策略队","members":["diao_chan","zhuge_liang","gardevoir","dragonite"],"level":18,"gear":1.65},
	{"id":"sustain","label":"多盾续航队","members":["squirtle","gardevoir","liu_bei","bulbasaur"],"level":15,"gear":1.25},
	{"id":"endgame","label":"秘境成型队","members":["guan_yu","lucario","gardevoir","dragonite"],"level":20,"gear":2.25}
]

var actors: Dictionary
var skills: Dictionary
var rng := RandomNumberGenerator.new()

func _init() -> void:
	actors = JSON.parse_string(FileAccess.get_file_as_string("res://data/actors.json"))
	skills = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	rng.seed = 20261014
	var failures: Array[String] = []
	var results: Dictionary = {}
	for party in PARTIES:
		var main10 := simulate(party, 10, false)
		var main15 := simulate(party, 15, false)
		var main20 := simulate(party, 20, false)
		var rift10 := simulate(party, 10, true)
		var rift20 := simulate(party, 20, true)
		results[party.id] = {"main10":main10,"main15":main15,"main20":main20,"rift10":rift10,"rift20":rift20}
		print("V07_BALANCE_PARTY id=%s main10=%.2f main15=%.2f main20=%.2f rift10=%.2f rift20=%.2f label=%s" % [party.id, main10, main15, main20, rift10, rift20, party.label])
	if float(results.classic.main10) < 0.60: failures.append("经典Lv10阵容无法稳定完成第一世界")
	if float(results.break.main15) < 0.60: failures.append("破甲阵容在同级后期没有合理成长收益")
	if float(results.burn.main15) < 0.55: failures.append("燃烧联动阵容无法形成有效Build")
	if float(results.control.rift10) < 0.45: failures.append("控制与护盾阵容无法进入秘境循环")
	if float(results.sustain.rift20) > 0.85: failures.append("低配多治疗护盾阵容接近无限生存")
	if float(results.endgame.rift20) < 0.50: failures.append("Lv20成型阵容无法挑战当前最高秘境")
	var low_level := {"members":["guan_yu","huang_zhong","lucario","diao_chan"],"level":7,"gear":1.0}
	if simulate(low_level, 18, false) > 0.20: failures.append("Lv7新增角色队仍可轻松越级第18关")
	if failures.is_empty(): print("V07_BALANCE_MATRIX_PASS parties=6 trials=%d main_and_rift=true armor_break=true burn=true control=true multi_sustain_not_immortal=true lv7_stage18_blocked=true" % TRIALS)
	else:
		for failure in failures: push_error("V07_BALANCE_MATRIX_FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func simulate(party: Dictionary, stage: int, rift: bool) -> float:
	var offense := 0.0; var sustain := 0.0; var ehp := 0.0
	for actor_id in party.members:
		var actor: Dictionary = actors[actor_id]; var level := int(party.level); var gear := float(party.gear)
		var attack := float(actor.attack) * (1.0 + (level - 1) * 0.06) + level * 2.4 * gear
		var hp := float(actor.max_hp) * (1.0 + (level - 1) * 0.08) + level * 17.0 * gear
		var defense := float(actor.defense) * (1.0 + (level - 1) * 0.05) + level * 1.05 * gear
		ehp += hp * (1.0 + defense * 0.012)
		var dps := attack / float(actor.attack_interval)
		var skill: Dictionary = skills[str(actor.skill)]
		var skill_dps := attack * float(skill.get("power", 0.5)) / maxf(3.5, float(skill.get("cooldown", 6.0)))
		if str(actor.get("basic_action", "damage")) == "heal": sustain += dps * 0.72 + skill_dps
		else: offense += dps + skill_dps
		match str(skill.get("type", "")):
			"armor_break_shot", "execute_cone", "piercing_shot": offense *= 1.045
			"burn_area": offense += attack * float(skill.get("dot_power", 0.2)) * float(skill.get("duration", 5.0)) / float(skill.get("cooldown", 6.0))
			"ally_guard", "shell_guard": sustain += hp * float(skill.get("power", 0.15)) / float(skill.get("cooldown", 7.0))
			"leech_vine": sustain += attack * 0.22
	var enemy_hp: float; var incoming: float
	if rift:
		var n := float(stage - 1)
		enemy_hp = 5200.0 * (1.0 + n * 0.24 + n * n * 0.018)
		incoming = 58.0 * (1.0 + n * 0.105 + n * n * 0.006) * 0.85
	else:
		enemy_hp = (1500.0 + stage * 720.0 + stage * stage * 85.0)
		incoming = (42.0 + stage * 14.0 + stage * stage * 1.2) * 0.55
	var clear_time := enemy_hp / maxf(1.0, offense)
	var survival := (ehp + sustain * minf(clear_time, 180.0) * 0.55) / maxf(1.0, incoming * clear_time)
	var clears := 0
	for _trial in range(TRIALS):
		var time_roll := clear_time * rng.randf_range(0.86, 1.16)
		var survival_roll := survival * rng.randf_range(0.80, 1.18)
		if time_roll <= 180.0 and survival_roll >= 0.82: clears += 1
	return float(clears) / TRIALS
