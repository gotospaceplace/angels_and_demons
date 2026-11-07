extends Node

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []


func _ready() -> void:
	print("=== Grenade Model Tests ===")
	print("GLB loading, per-type visual, sphere fallback")
	print("")

	test_model_paths_cover_all_types()
	test_he_grenade_path_valid()
	test_flash_grenade_path_valid()
	test_smoke_grenade_path_valid()
	test_he_grenade_loads()
	test_flash_grenade_loads()
	test_smoke_grenade_loads()

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


func test_model_paths_cover_all_types() -> void:
	var paths: Dictionary = GrenadeProjectile.GRENADE_MODEL_PATHS
	var has_he := paths.has(GrenadeProjectile.Type.HE)
	var has_flash := paths.has(GrenadeProjectile.Type.FLASH)
	var has_smoke := paths.has(GrenadeProjectile.Type.SMOKE)
	if has_he and has_flash and has_smoke:
		_pass("test_model_paths_cover_all_types",
			"all 3 grenade types have model paths")
	else:
		_fail("test_model_paths_cover_all_types",
			"HE=%s FLASH=%s SMOKE=%s" % [has_he, has_flash, has_smoke])


func test_he_grenade_path_valid() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.HE]
	if path.ends_with(".glb"):
		_pass("test_he_grenade_path_valid",
			"HE path is a .glb: %s" % path)
	else:
		_fail("test_he_grenade_path_valid",
			"expected .glb path, got: %s" % path)


func test_flash_grenade_path_valid() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.FLASH]
	if path.ends_with(".glb"):
		_pass("test_flash_grenade_path_valid",
			"FLASH path is a .glb: %s" % path)
	else:
		_fail("test_flash_grenade_path_valid",
			"expected .glb path, got: %s" % path)


func test_smoke_grenade_path_valid() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.SMOKE]
	if path.ends_with(".glb"):
		_pass("test_smoke_grenade_path_valid",
			"SMOKE path is a .glb: %s" % path)
	else:
		_fail("test_smoke_grenade_path_valid",
			"expected .glb path, got: %s" % path)


func test_he_grenade_loads() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.HE]
	var scene: PackedScene = load(path)
	if scene:
		_pass("test_he_grenade_loads",
			"HE grenade GLB loaded successfully")
	else:
		_fail("test_he_grenade_loads",
			"failed to load %s" % path)


func test_flash_grenade_loads() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.FLASH]
	var scene: PackedScene = load(path)
	if scene:
		_pass("test_flash_grenade_loads",
			"FLASH grenade GLB loaded successfully")
	else:
		_fail("test_flash_grenade_loads",
			"failed to load %s" % path)


func test_smoke_grenade_loads() -> void:
	var path: String = GrenadeProjectile.GRENADE_MODEL_PATHS[GrenadeProjectile.Type.SMOKE]
	var scene: PackedScene = load(path)
	if scene:
		_pass("test_smoke_grenade_loads",
			"SMOKE grenade GLB loaded successfully")
	else:
		_fail("test_smoke_grenade_loads",
			"failed to load %s" % path)
