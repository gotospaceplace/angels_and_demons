extends Node

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []
var vm: Viewmodel


func _ready() -> void:
	print("=== Viewmodel Tests ===")
	print("FP arms, weapon swap, render layer, animations")
	print("")

	vm = Viewmodel.new()
	vm.name = "TestViewmodel"
	add_child(vm)
	vm.setup("angels")

	test_render_layer_constant()
	test_viewmodel_fov_constant()
	test_fp_arms_paths_defined()
	test_weapon_model_paths_cover_all()
	test_weapon_offsets_defined()
	test_setup_creates_arms()
	test_set_weapon_creates_visual()
	test_set_weapon_changes_idx()
	test_switch_weapon_replaces_visual()
	test_invalid_weapon_fallback()
	test_visibility_toggle()
	test_idle_state_default()
	test_play_fire_sets_state()
	test_play_reload_sets_state()
	test_play_equip_sets_state()
	test_fire_kick_per_weapon()
	test_fire_anim_durations_defined()
	test_bob_constants()

	vm.queue_free()
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


func test_render_layer_constant() -> void:
	if Viewmodel.RENDER_LAYER == 2:
		_pass("test_render_layer_constant",
			"RENDER_LAYER = 2 (separate from world)")
	else:
		_fail("test_render_layer_constant",
			"expected 2, got %d" % Viewmodel.RENDER_LAYER)


func test_viewmodel_fov_constant() -> void:
	if absf(Viewmodel.VIEWMODEL_FOV - 54.0) < 0.1:
		_pass("test_viewmodel_fov_constant",
			"VIEWMODEL_FOV = %.1f" % Viewmodel.VIEWMODEL_FOV)
	else:
		_fail("test_viewmodel_fov_constant",
			"expected 54.0, got %.1f" % Viewmodel.VIEWMODEL_FOV)


func test_fp_arms_paths_defined() -> void:
	if Viewmodel.FP_ARMS_PATHS.has("angels"):
		_pass("test_fp_arms_paths_defined",
			"angels FP arms path defined")
	else:
		_fail("test_fp_arms_paths_defined",
			"no angels entry in FP_ARMS_PATHS")


func test_weapon_model_paths_cover_all() -> void:
	var missing := []
	for i in range(5):
		if not Viewmodel.WEAPON_MODEL_PATHS.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_weapon_model_paths_cover_all",
			"all 5 weapon indices have viewmodel paths")
	else:
		_fail("test_weapon_model_paths_cover_all",
			"missing: %s" % str(missing))


func test_weapon_offsets_defined() -> void:
	var missing := []
	for i in range(5):
		if not Viewmodel.WEAPON_OFFSETS.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_weapon_offsets_defined",
			"all 5 weapon indices have position offsets")
	else:
		_fail("test_weapon_offsets_defined",
			"missing: %s" % str(missing))


func test_setup_creates_arms() -> void:
	if vm._arms_root != null:
		_pass("test_setup_creates_arms",
			"FP arms model loaded")
	else:
		_fail("test_setup_creates_arms",
			"_arms_root is null after setup")


func test_set_weapon_creates_visual() -> void:
	vm.set_weapon(2)
	if vm._weapon_visual != null:
		_pass("test_set_weapon_creates_visual",
			"weapon visual created for idx 2")
	else:
		_fail("test_set_weapon_creates_visual",
			"_weapon_visual is null after set_weapon(2)")


func test_set_weapon_changes_idx() -> void:
	vm.set_weapon(1)
	if vm.get_current_weapon_idx() == 1:
		_pass("test_set_weapon_changes_idx",
			"current weapon idx updated to 1")
	else:
		_fail("test_set_weapon_changes_idx",
			"expected 1, got %d" % vm.get_current_weapon_idx())


func test_switch_weapon_replaces_visual() -> void:
	vm.set_weapon(2)
	var first := vm._weapon_visual
	vm.set_weapon(0)
	var second := vm._weapon_visual
	if second != null and second != first:
		_pass("test_switch_weapon_replaces_visual",
			"weapon switch replaced visual node")
	else:
		_fail("test_switch_weapon_replaces_visual",
			"visual not replaced on switch")


func test_invalid_weapon_fallback() -> void:
	vm.set_weapon(99)
	if vm._weapon_visual != null:
		_pass("test_invalid_weapon_fallback",
			"unknown idx 99 gets fallback visual")
	else:
		_fail("test_invalid_weapon_fallback",
			"no fallback visual for unknown idx")


func test_visibility_toggle() -> void:
	vm.set_visible_viewmodel(false)
	var hidden := not vm.visible
	vm.set_visible_viewmodel(true)
	var shown := vm.visible
	if hidden and shown:
		_pass("test_visibility_toggle",
			"visibility toggles correctly")
	else:
		_fail("test_visibility_toggle",
			"hidden=%s shown=%s" % [hidden, shown])


func test_idle_state_default() -> void:
	vm.set_weapon(2)
	if vm.get_anim_state() == Viewmodel.AnimState.IDLE:
		_pass("test_idle_state_default",
			"default anim state is IDLE")
	else:
		_fail("test_idle_state_default",
			"expected IDLE(0), got %d" % vm.get_anim_state())


func test_play_fire_sets_state() -> void:
	vm.play_fire()
	if vm.get_anim_state() == Viewmodel.AnimState.FIRE:
		_pass("test_play_fire_sets_state",
			"play_fire() sets state to FIRE")
	else:
		_fail("test_play_fire_sets_state",
			"expected FIRE(1), got %d" % vm.get_anim_state())
	vm._anim_state = Viewmodel.AnimState.IDLE


func test_play_reload_sets_state() -> void:
	vm.play_reload(2.5)
	if vm.get_anim_state() == Viewmodel.AnimState.RELOAD:
		_pass("test_play_reload_sets_state",
			"play_reload() sets state to RELOAD")
	else:
		_fail("test_play_reload_sets_state",
			"expected RELOAD(2), got %d" % vm.get_anim_state())
	vm._anim_state = Viewmodel.AnimState.IDLE


func test_play_equip_sets_state() -> void:
	vm.play_equip(1.0)
	if vm.get_anim_state() == Viewmodel.AnimState.EQUIP:
		_pass("test_play_equip_sets_state",
			"play_equip() sets state to EQUIP")
	else:
		_fail("test_play_equip_sets_state",
			"expected EQUIP(3), got %d" % vm.get_anim_state())
	vm._anim_state = Viewmodel.AnimState.IDLE


func test_fire_kick_per_weapon() -> void:
	var missing := []
	for i in range(5):
		if not Viewmodel.FIRE_KICK.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_fire_kick_per_weapon",
			"all 5 weapons have fire kick parameters")
	else:
		_fail("test_fire_kick_per_weapon",
			"missing kick data: %s" % str(missing))


func test_fire_anim_durations_defined() -> void:
	var missing := []
	for i in range(5):
		if not Viewmodel.FIRE_ANIM_DURATIONS.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_fire_anim_durations_defined",
			"all 5 weapons have fire animation durations")
	else:
		_fail("test_fire_anim_durations_defined",
			"missing durations: %s" % str(missing))


func test_bob_constants() -> void:
	var ok := (Viewmodel.IDLE_BOB_SPEED > 0.0
		and Viewmodel.WALK_BOB_SPEED > Viewmodel.IDLE_BOB_SPEED
		and Viewmodel.WALK_BOB_X > Viewmodel.IDLE_BOB_X
		and Viewmodel.WALK_BOB_Y > Viewmodel.IDLE_BOB_Y)
	if ok:
		_pass("test_bob_constants",
			"walk bob faster/larger than idle bob")
	else:
		_fail("test_bob_constants",
			"walk bob should be faster and larger than idle bob")
