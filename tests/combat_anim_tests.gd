extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")
const WR := preload("res://shared/scripts/weapon_registry.gd")

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []
var model: CharacterModel


func _ready() -> void:
	print("=== Combat Animation Tests ===")
	print("Weapon overlay layer, combat clips, event wiring")
	print("")

	model = CharacterModel.new()
	model.name = "TestCharacterModel"
	add_child(model)
	model.setup("angels")

	test_upper_body_bones_constant()
	test_weapon_category_map_covers_all()
	test_hold_anim_map_complete()
	test_fire_anim_map_complete()
	test_combat_anims_in_library()
	test_weapon_overlay_nodes_exist()
	test_weapon_oneshot_exists()
	test_weapon_layer_blend_default()
	test_initial_weapon_state_sets_hold()
	test_weapon_switch_triggers_oneshot()
	test_fire_triggers_on_ammo_decrease()
	test_ammo_increase_no_fire()
	test_hold_anim_changes_per_category()
	test_fire_anim_length_nonzero()
	test_switch_anim_length()
	test_melee_slash_length()

	model.queue_free()
	_print_summary()


func _pass(test_name: String, msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  PASS %s" % msg)


func _fail(test_name: String, msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [test_name, msg])
	print("  RUN  %s" % test_name)
	print("  FAIL %s" % msg)


func _print_summary() -> void:
	print("")
	print("=== Results ===")
	for r in results:
		print(r)
	print("")
	var total := tests_passed + tests_failed
	print("%d/%d passed, %d failed" % [tests_passed, total, tests_failed])
	if tests_failed > 0:
		print("FAILED")
		get_tree().quit(1)
	else:
		print("ALL PASSED")
		get_tree().quit(0)


func test_upper_body_bones_constant() -> void:
	var bones: Array = CharacterModel.UPPER_BODY_BONES
	if bones.size() == 13:
		_pass("test_upper_body_bones_constant",
			"13 upper body bones defined for filter")
	else:
		_fail("test_upper_body_bones_constant",
			"expected 13 bones, got %d" % bones.size())


func test_weapon_category_map_covers_all() -> void:
	var weapons := WR.create_all()
	var missing := []
	for i in range(weapons.size()):
		if not CharacterModel.WEAPON_CATEGORY.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_weapon_category_map_covers_all",
			"all %d weapon indices mapped" % weapons.size())
	else:
		_fail("test_weapon_category_map_covers_all",
			"missing indices: %s" % str(missing))


func test_hold_anim_map_complete() -> void:
	var categories := ["melee", "pistol", "rifle"]
	var missing := []
	for cat in categories:
		if not CharacterModel.HOLD_ANIM_MAP.has(cat):
			missing.append(cat)
	if missing.is_empty():
		_pass("test_hold_anim_map_complete",
			"hold anims for all 3 categories")
	else:
		_fail("test_hold_anim_map_complete",
			"missing: %s" % str(missing))


func test_fire_anim_map_complete() -> void:
	var categories := ["melee", "pistol", "rifle"]
	var missing := []
	for cat in categories:
		if not CharacterModel.FIRE_ANIM_MAP.has(cat):
			missing.append(cat)
	if missing.is_empty():
		_pass("test_fire_anim_map_complete",
			"fire anims for all 3 categories")
	else:
		_fail("test_fire_anim_map_complete",
			"missing: %s" % str(missing))


func test_combat_anims_in_library() -> void:
	if not model.anim_tree:
		_fail("test_combat_anims_in_library", "no AnimationTree")
		return
	var expected := [
		&"rifle_hold", &"rifle_fire",
		&"pistol_hold", &"pistol_fire",
		&"melee_hold", &"melee_slash",
		&"weapon_switch",
	]
	var missing := []
	for anim_name in expected:
		if not model.anim_tree.has_animation(anim_name):
			missing.append(anim_name)
	if missing.is_empty():
		_pass("test_combat_anims_in_library",
			"all 7 combat animations registered")
	else:
		_fail("test_combat_anims_in_library",
			"missing: %s" % str(missing))


func test_weapon_overlay_nodes_exist() -> void:
	if model._weapon_hold_node and model._weapon_action_node:
		_pass("test_weapon_overlay_nodes_exist",
			"weapon_hold and weapon_action nodes wired")
	else:
		_fail("test_weapon_overlay_nodes_exist",
			"hold=%s action=%s" % [
				model._weapon_hold_node != null,
				model._weapon_action_node != null])


func test_weapon_oneshot_exists() -> void:
	if not model.anim_tree or not model.anim_tree.tree_root:
		_fail("test_weapon_oneshot_exists", "no blend tree")
		return
	var tree: AnimationNodeBlendTree = model.anim_tree.tree_root
	var node := tree.get_node(&"weapon_oneshot")
	if node is AnimationNodeOneShot:
		_pass("test_weapon_oneshot_exists",
			"weapon_oneshot is AnimationNodeOneShot")
	else:
		_fail("test_weapon_oneshot_exists",
			"weapon_oneshot not found or wrong type")


func test_weapon_layer_blend_default() -> void:
	if not model.anim_tree:
		_fail("test_weapon_layer_blend_default", "no AnimationTree")
		return
	var blend: float = model.anim_tree.get(&"parameters/weapon_layer/blend_amount")
	if absf(blend - 1.0) < 0.01:
		_pass("test_weapon_layer_blend_default",
			"weapon layer blend = %.2f (fully active)" % blend)
	else:
		_fail("test_weapon_layer_blend_default",
			"expected 1.0, got %.2f" % blend)


func test_initial_weapon_state_sets_hold() -> void:
	model._current_weapon_idx = -1
	model._prev_ammo = -1
	model.apply_weapon_state(2, 30)
	if model._current_weapon_idx == 2 and model._weapon_hold_node:
		var anim_name: StringName = model._weapon_hold_node.animation
		if anim_name == &"rifle_hold":
			_pass("test_initial_weapon_state_sets_hold",
				"AK47 (idx 2) -> rifle_hold")
		else:
			_fail("test_initial_weapon_state_sets_hold",
				"expected rifle_hold, got %s" % anim_name)
	else:
		_fail("test_initial_weapon_state_sets_hold",
			"weapon idx not set or no hold node")


func test_weapon_switch_triggers_oneshot() -> void:
	model._current_weapon_idx = 2
	model._prev_ammo = 30
	model.apply_weapon_state(1, 12)
	if model._weapon_action_node:
		var anim_name: StringName = model._weapon_action_node.animation
		if anim_name == &"weapon_switch":
			_pass("test_weapon_switch_triggers_oneshot",
				"switching 2->1 plays weapon_switch")
		else:
			_fail("test_weapon_switch_triggers_oneshot",
				"expected weapon_switch, got %s" % anim_name)
	else:
		_fail("test_weapon_switch_triggers_oneshot", "no action node")


func test_fire_triggers_on_ammo_decrease() -> void:
	model._current_weapon_idx = 2
	model._prev_ammo = 30
	model.apply_weapon_state(2, 29)
	if model._weapon_action_node:
		var anim_name: StringName = model._weapon_action_node.animation
		if anim_name == &"rifle_fire":
			_pass("test_fire_triggers_on_ammo_decrease",
				"ammo 30->29 triggers rifle_fire")
		else:
			_fail("test_fire_triggers_on_ammo_decrease",
				"expected rifle_fire, got %s" % anim_name)
	else:
		_fail("test_fire_triggers_on_ammo_decrease", "no action node")


func test_ammo_increase_no_fire() -> void:
	model._current_weapon_idx = 2
	model._prev_ammo = 20
	if model._weapon_action_node:
		model._weapon_action_node.animation = &"rifle_hold"
	model.apply_weapon_state(2, 30)
	if model._weapon_action_node:
		var anim_name: StringName = model._weapon_action_node.animation
		if anim_name == &"rifle_hold":
			_pass("test_ammo_increase_no_fire",
				"ammo 20->30 (reload) does not trigger fire")
		else:
			_fail("test_ammo_increase_no_fire",
				"unexpected anim change to %s" % anim_name)
	else:
		_fail("test_ammo_increase_no_fire", "no action node")


func test_hold_anim_changes_per_category() -> void:
	model._current_weapon_idx = -1
	model._prev_ammo = -1
	model.apply_weapon_state(0, 0)
	var melee_hold: StringName = model._weapon_hold_node.animation if model._weapon_hold_node else &""

	model._current_weapon_idx = -1
	model._prev_ammo = -1
	model.apply_weapon_state(1, 12)
	var pistol_hold: StringName = model._weapon_hold_node.animation if model._weapon_hold_node else &""

	model._current_weapon_idx = -1
	model._prev_ammo = -1
	model.apply_weapon_state(2, 30)
	var rifle_hold: StringName = model._weapon_hold_node.animation if model._weapon_hold_node else &""

	if melee_hold == &"melee_hold" and pistol_hold == &"pistol_hold" and rifle_hold == &"rifle_hold":
		_pass("test_hold_anim_changes_per_category",
			"melee/pistol/rifle each get correct hold pose")
	else:
		_fail("test_hold_anim_changes_per_category",
			"melee=%s pistol=%s rifle=%s" % [melee_hold, pistol_hold, rifle_hold])


func test_fire_anim_length_nonzero() -> void:
	if not model.anim_tree:
		_fail("test_fire_anim_length_nonzero", "no AnimationTree")
		return
	var all_ok := true
	var msgs := []
	for anim_name in [&"rifle_fire", &"pistol_fire"]:
		var anim: Animation = model.anim_tree.get_animation(anim_name)
		if not anim or anim.length <= 0.0:
			all_ok = false
			msgs.append("%s missing or zero-length" % anim_name)
	if all_ok:
		_pass("test_fire_anim_length_nonzero",
			"rifle_fire and pistol_fire have nonzero length")
	else:
		_fail("test_fire_anim_length_nonzero", ", ".join(msgs))


func test_switch_anim_length() -> void:
	if not model.anim_tree:
		_fail("test_switch_anim_length", "no AnimationTree")
		return
	var anim: Animation = model.anim_tree.get_animation(&"weapon_switch")
	if anim and absf(anim.length - 0.5) < 0.01:
		_pass("test_switch_anim_length",
			"weapon_switch = %.2fs" % anim.length)
	else:
		var len_str := "%.2f" % anim.length if anim else "null"
		_fail("test_switch_anim_length",
			"expected ~0.5s, got %s" % len_str)


func test_melee_slash_length() -> void:
	if not model.anim_tree:
		_fail("test_melee_slash_length", "no AnimationTree")
		return
	var anim: Animation = model.anim_tree.get_animation(&"melee_slash")
	if anim and absf(anim.length - 0.4) < 0.01:
		_pass("test_melee_slash_length",
			"melee_slash = %.2fs" % anim.length)
	else:
		var len_str := "%.2f" % anim.length if anim else "null"
		_fail("test_melee_slash_length",
			"expected ~0.4s, got %s" % len_str)
