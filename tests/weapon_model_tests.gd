extends Node

const WR := preload("res://shared/scripts/weapon_registry.gd")

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []
var model: CharacterModel


func _ready() -> void:
	print("=== Weapon Model Tests ===")
	print("GLB loading, per-weapon models, fallback behavior")
	print("")

	model = CharacterModel.new()
	model.name = "TestCharacterModel"
	add_child(model)
	model.setup("angels")

	test_weapon_model_paths_cover_all()
	test_weapon_model_paths_format()
	test_set_weapon_creates_visual()
	test_switch_weapon_replaces_visual()
	test_all_weapons_produce_visual()
	test_invalid_weapon_idx_fallback()
	test_no_weapon_attach_safe()

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


func test_weapon_model_paths_cover_all() -> void:
	var weapons := WR.create_all()
	var missing := []
	for i in range(weapons.size()):
		if not CharacterModel.WEAPON_MODEL_PATHS.has(i):
			missing.append(i)
	if missing.is_empty():
		_pass("test_weapon_model_paths_cover_all",
			"all %d weapon indices have model paths" % weapons.size())
	else:
		_fail("test_weapon_model_paths_cover_all",
			"missing indices: %s" % str(missing))


func test_weapon_model_paths_format() -> void:
	var bad := []
	for idx in CharacterModel.WEAPON_MODEL_PATHS:
		var path: String = CharacterModel.WEAPON_MODEL_PATHS[idx]
		if not path.begins_with("res://assets/weapons/"):
			bad.append("%d: %s" % [idx, path])
		elif not path.ends_with("_world.glb"):
			bad.append("%d: %s (not _world.glb)" % [idx, path])
	if bad.is_empty():
		_pass("test_weapon_model_paths_format",
			"all paths follow assets/weapons/<name>/<name>_world.glb pattern")
	else:
		_fail("test_weapon_model_paths_format",
			"bad paths: %s" % ", ".join(bad))


func test_set_weapon_creates_visual() -> void:
	model.set_weapon_model(2)
	if model.current_weapon_visual != null:
		_pass("test_set_weapon_creates_visual",
			"set_weapon_model(2) created visual node")
	else:
		_fail("test_set_weapon_creates_visual",
			"current_weapon_visual is null after set_weapon_model(2)")


func test_switch_weapon_replaces_visual() -> void:
	model.set_weapon_model(2)
	var first := model.current_weapon_visual
	model.set_weapon_model(1)
	var second := model.current_weapon_visual
	if second != null and second != first:
		_pass("test_switch_weapon_replaces_visual",
			"switching weapon replaced the visual node")
	elif second == first:
		_fail("test_switch_weapon_replaces_visual",
			"visual was not replaced on weapon switch")
	else:
		_fail("test_switch_weapon_replaces_visual",
			"visual is null after switch")


func test_all_weapons_produce_visual() -> void:
	var failed := []
	for idx in CharacterModel.WEAPON_MODEL_PATHS:
		model.set_weapon_model(idx)
		if model.current_weapon_visual == null:
			failed.append(idx)
	if failed.is_empty():
		_pass("test_all_weapons_produce_visual",
			"all %d weapons produce a visual node" % CharacterModel.WEAPON_MODEL_PATHS.size())
	else:
		_fail("test_all_weapons_produce_visual",
			"no visual for indices: %s" % str(failed))


func test_invalid_weapon_idx_fallback() -> void:
	model.set_weapon_model(99)
	if model.current_weapon_visual != null:
		_pass("test_invalid_weapon_idx_fallback",
			"unknown weapon idx 99 falls back to box mesh")
	else:
		_fail("test_invalid_weapon_idx_fallback",
			"no fallback visual for unknown weapon idx")


func test_no_weapon_attach_safe() -> void:
	var saved := model.weapon_attach
	model.weapon_attach = null
	model.set_weapon_model(2)
	var result := model.current_weapon_visual == null
	model.weapon_attach = saved
	if result:
		_pass("test_no_weapon_attach_safe",
			"set_weapon_model with no weapon_attach does not crash")
	else:
		_fail("test_no_weapon_attach_safe",
			"visual created despite no weapon_attach")
