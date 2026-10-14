extends SceneTree

const BattleControllerScript = preload("res://scripts/battle_controller.gd")
const CharacterUIScript = preload("res://scripts/character_ui.gd")
const CombatStatsScript = preload("res://scripts/combat_stats.gd")
const CraftingManagerScript = preload("res://scripts/crafting_manager.gd")
const InventoryManagerScript = preload("res://scripts/inventory_manager.gd")
const ProgressionManagerScript = preload("res://scripts/progression_manager.gd")
const ShopManagerScript = preload("res://scripts/shop_manager.gd")

class FakeBattle extends Node:
	var progression
	var inventory
	var equipment_config: Dictionary
	var actors: Dictionary
	var skills: Dictionary
	var passives_config: Dictionary
	var general_skills_config: Dictionary
	func get_hero(_actor_id: String): return null
	func rebuild_party() -> void: pass

var equipment_config: Dictionary

func _initialize() -> void:
	equipment_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	var failures: Array[String] = []
	_test_auto_processing(failures)
	await _test_skill_scroll(failures)
	if failures.is_empty():
		print("V082_AUTO_EQUIPMENT_SCROLL_VALIDATION_PASS auto=true capacity=true persistence=true scroll=true")
		quit(0)
		return
	for failure in failures:
		push_error("V082_AUTO_EQUIPMENT_SCROLL_VALIDATION_FAIL: " + failure)
	quit(1)

func _item(id: String, quality: String, rank: int, special: bool = false) -> Dictionary:
	return {
		"instance_id":id, "template_id":"test", "name":id, "slot":"helmet",
		"compatible_slots":["helmet"], "quality":quality, "quality_rank":rank,
		"level":5, "base_stats":{"defense":1.0}, "affixes":[],
		"special_effects":["test_effect"] if special else [], "locked":false
	}

func _auto_controller():
	var controller = BattleControllerScript.new()
	controller.equipment_config = equipment_config
	controller.progression = ProgressionManagerScript.new()
	controller.progression.save_path = "user://v082_auto_progress_test.json"
	controller.inventory = InventoryManagerScript.new()
	controller.inventory.setup(equipment_config)
	controller.inventory.save_path = "user://v082_auto_inventory_test.json"
	controller.crafting = CraftingManagerScript.new()
	controller.crafting.setup(controller.inventory, controller.progression, equipment_config, null)
	controller.shop = ShopManagerScript.new()
	controller.shop.setup(controller.inventory, controller.progression, null, {})
	controller.combat_stats = CombatStatsScript.new()
	controller.combat_stats.reset()
	return controller

func _test_auto_processing(failures: Array[String]) -> void:
	var battle = _auto_controller()
	var p = battle.progression
	# Both features are off for new and legacy saves.
	if not battle.auto_process_new_equipment(_item("off", "white", 0)).is_empty(): failures.append("default-off setting processed a drop")
	var old = ProgressionManagerScript.new()
	old.apply_payload({"version":"0.8", "gold":7})
	if bool(old.auto_equipment_settings.sell_enabled) or bool(old.auto_equipment_settings.dismantle_enabled): failures.append("legacy payload did not migrate with automation disabled")

	p.set_auto_equipment_setting("sell_enabled", true, false)
	p.set_auto_equipment_setting("sell_max_quality", "white", false)
	var white := _item("white_once", "white", 0)
	var expected_gold: int = battle.shop.sell_price(white)
	if str(battle.auto_process_new_equipment(white).get("action", "")) != "sell" or p.gold != expected_gold: failures.append("white auto-sell used the wrong rule or value")
	if not battle.auto_process_new_equipment(white).is_empty() or p.gold != expected_gold: failures.append("one equipment instance was settled more than once")
	if not battle.auto_process_new_equipment(_item("green_keep", "green", 1)).is_empty(): failures.append("white threshold processed green equipment")

	p.set_auto_equipment_setting("sell_max_quality", "blue", false)
	for spec in [["w", "white", 0], ["g", "green", 1], ["b", "blue", 2]]:
		if str(battle.auto_process_new_equipment(_item(str(spec[0]), str(spec[1]), int(spec[2]))).get("action", "")) != "sell": failures.append("blue threshold missed " + str(spec[1]))
	if not battle.auto_process_new_equipment(_item("purple_keep", "purple", 3)).is_empty(): failures.append("blue threshold processed purple equipment")

	p.set_auto_equipment_setting("dismantle_enabled", true, false)
	p.set_auto_equipment_setting("dismantle_max_quality", "green", false)
	p.set_auto_equipment_setting("priority", "dismantle", false)
	if str(battle.auto_process_new_equipment(_item("overlap_d", "green", 1)).get("action", "")) != "dismantle": failures.append("dismantle conflict priority failed")
	p.set_auto_equipment_setting("priority", "sell", false)
	if str(battle.auto_process_new_equipment(_item("overlap_s", "green", 1)).get("action", "")) != "sell": failures.append("sell conflict priority failed")

	var locked := _item("locked", "white", 0); locked.locked = true
	var protected := _item("protected", "white", 0); protected.auto_process_protected = true
	if not battle.auto_process_new_equipment(locked).is_empty() or not battle.auto_process_new_equipment(protected).is_empty() or not battle.auto_process_new_equipment(_item("special", "white", 0, true)).is_empty(): failures.append("protected equipment was automatically processed")
	var equipped := _item("equipped", "white", 0)
	battle.inventory.add_item(equipped, false); battle.inventory.equip_item("liu_bei", "equipped", "helmet", false)
	if not battle.auto_process_new_equipment(equipped).is_empty(): failures.append("equipped item was automatically processed")

	# A full backpack must not block direct conversion.
	battle.inventory.capacity = battle.inventory.items.size()
	p.set_auto_equipment_setting("sell_enabled", false, false)
	p.set_auto_equipment_setting("priority", "dismantle", false)
	var dust_before: int = int(p.materials.salvage_dust)
	var full_result: Dictionary = battle.auto_process_new_equipment(_item("full_green", "green", 1))
	if str(full_result.get("action", "")) != "dismantle" or int(p.materials.salvage_dust) <= dust_before: failures.append("full backpack blocked eligible dismantle")

	# Settings round-trip without affecting unrelated progress.
	p.gold = 321
	p.set_auto_equipment_setting("sell_enabled", true, false)
	p.set_auto_equipment_setting("sell_max_quality", "blue", false)
	p.save_to_disk()
	var loaded = ProgressionManagerScript.new(); loaded.save_path = p.save_path
	if not loaded.load_from_disk() or not bool(loaded.auto_equipment_settings.sell_enabled) or str(loaded.auto_equipment_settings.sell_max_quality) != "blue" or loaded.gold != 321: failures.append("auto settings persistence changed or lost save data")
	for path in [p.save_path, battle.inventory.save_path]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	battle.progression.free(); battle.inventory.free(); battle.free(); old.free(); loaded.free()

func _test_skill_scroll(failures: Array[String]) -> void:
	var fake := FakeBattle.new()
	fake.equipment_config = equipment_config
	fake.actors = JSON.parse_string(FileAccess.get_file_as_string("res://data/actors.json"))
	fake.skills = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	fake.passives_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/passives.json"))
	fake.general_skills_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/general_skills.json"))
	var v08: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/v08_content.json"))
	fake.actors.merge(v08.get("actors", {}), true); fake.skills.merge(v08.get("skills", {}), true); fake.passives_config.merge(v08.get("passives", {}), true); fake.general_skills_config.merge(v08.get("general_skills", {}), true)
	fake.progression = ProgressionManagerScript.new()
	fake.progression.progression_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))
	fake.progression.ensure_growth_layout()
	fake.inventory = InventoryManagerScript.new(); fake.inventory.setup(equipment_config)
	root.add_child(fake)
	var ui = CharacterUIScript.new(); root.add_child(ui); ui.setup(fake); ui.open("skills")
	await process_frame; await process_frame
	ui.skill_scroll.scroll_vertical = mini(240, int(ui.skill_scroll.get_v_scroll_bar().max_value - ui.skill_scroll.get_v_scroll_bar().page))
	var before_scroll: int = ui.skill_scroll.scroll_vertical
	var first_child = ui.skills_box.get_child(0)
	fake.progression.gold += 1
	fake.progression.changed.emit()
	await process_frame
	if ui.skills_box.get_child(0) != first_child or ui.skill_scroll.scroll_vertical != before_scroll: failures.append("ordinary progression refresh rebuilt or moved the skill list")
	ui.refresh_skills(true)
	await process_frame; await process_frame
	if abs(ui.skill_scroll.scroll_vertical - before_scroll) > 2: failures.append("necessary skill rebuild did not restore scroll position")
	ui._set_skill_world_filter("三国")
	await process_frame; await process_frame
	if ui.skill_scroll.scroll_vertical != 0: failures.append("skill filter change did not reset to a predictable position")
	if _has_focusable_button(ui.skills_box): failures.append("skill buttons can still steal scroll focus")
	ui.queue_free(); await process_frame
	fake.progression.free(); fake.inventory.free(); fake.queue_free()
	await process_frame

func _has_focusable_button(node: Node) -> bool:
	for child in node.get_children():
		if child is Button and child.focus_mode != Control.FOCUS_NONE: return true
		if _has_focusable_button(child): return true
	return false
