extends Node

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []


func _ready() -> void:
	print("=== D1 Brute Character Tests ===")
	print("Model paths, GLB loading, faction switching, viewmodel paths")
	print("")

	test_model_paths_has_demons()
	test_model_paths_has_angels()
	test_d1_glb_file_exists()
	test_d1_fp_glb_file_exists()
	test_character_model_setup_demons()
	test_character_model_set_faction()
	test_viewmodel_fp_arms_paths()
	test_team_get_faction_angels()
	test_team_get_faction_demons()
	test_team_get_faction_default()
	test_remote_player_set_faction()
	test_shared_skeleton_compat()

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


func test_model_paths_has_demons() -> void:
	if CharacterModel.MODEL_PATHS.has("demons"):
		_pass("test_model_paths_has_demons",
			"MODEL_PATHS contains 'demons' entry")
	else:
		_fail("test_model_paths_has_demons",
			"MODEL_PATHS missing 'demons' key")


func test_model_paths_has_angels() -> void:
	if CharacterModel.MODEL_PATHS.has("angels"):
		_pass("test_model_paths_has_angels",
			"MODEL_PATHS still contains 'angels' entry")
	else:
		_fail("test_model_paths_has_angels",
			"MODEL_PATHS missing 'angels' key")


func test_d1_glb_file_exists() -> void:
	var path: String = CharacterModel.MODEL_PATHS["demons"]
	if ResourceLoader.exists(path):
		_pass("test_d1_glb_file_exists",
			"D1 Brute GLB found at %s" % path)
	else:
		_fail("test_d1_glb_file_exists",
			"D1 Brute GLB not found at %s" % path)


func test_d1_fp_glb_file_exists() -> void:
	var path: String = Viewmodel.FP_ARMS_PATHS["demons"]
	if ResourceLoader.exists(path):
		_pass("test_d1_fp_glb_file_exists",
			"D1 FP arms GLB found at %s" % path)
	else:
		_fail("test_d1_fp_glb_file_exists",
			"D1 FP arms GLB not found at %s" % path)


func test_character_model_setup_demons() -> void:
	var cm := CharacterModel.new()
	cm.name = "TestD1Setup"
	add_child(cm)
	cm.setup("demons")
	var has_skeleton := cm.skeleton != null
	var has_mesh := cm.mesh_instance != null
	cm.queue_free()
	if has_skeleton and has_mesh:
		_pass("test_character_model_setup_demons",
			"setup('demons') loads skeleton and mesh")
	else:
		_fail("test_character_model_setup_demons",
			"skeleton=%s mesh=%s" % [has_skeleton, has_mesh])


func test_character_model_set_faction() -> void:
	var cm := CharacterModel.new()
	cm.name = "TestFactionSwitch"
	add_child(cm)
	cm.setup("angels")
	var angels_mesh := cm.mesh_instance
	cm.set_faction("demons")
	var demons_mesh := cm.mesh_instance
	var switched := demons_mesh != null and demons_mesh != angels_mesh
	cm.queue_free()
	if switched:
		_pass("test_character_model_set_faction",
			"set_faction() reloads mesh for new faction")
	else:
		_fail("test_character_model_set_faction",
			"mesh did not change on faction switch")


func test_viewmodel_fp_arms_paths() -> void:
	if Viewmodel.FP_ARMS_PATHS.has("demons") and Viewmodel.FP_ARMS_PATHS.has("angels"):
		_pass("test_viewmodel_fp_arms_paths",
			"FP_ARMS_PATHS has both 'angels' and 'demons'")
	else:
		_fail("test_viewmodel_fp_arms_paths",
			"FP_ARMS_PATHS missing faction entries")


func test_team_get_faction_angels() -> void:
	var faction := Team.get_faction(Team.Id.ANGELS)
	if faction == "angels":
		_pass("test_team_get_faction_angels",
			"Team.get_faction(ANGELS) = 'angels'")
	else:
		_fail("test_team_get_faction_angels",
			"got '%s', expected 'angels'" % faction)


func test_team_get_faction_demons() -> void:
	var faction := Team.get_faction(Team.Id.DEMONS)
	if faction == "demons":
		_pass("test_team_get_faction_demons",
			"Team.get_faction(DEMONS) = 'demons'")
	else:
		_fail("test_team_get_faction_demons",
			"got '%s', expected 'demons'" % faction)


func test_team_get_faction_default() -> void:
	var faction := Team.get_faction(Team.Id.UNASSIGNED)
	if faction == "angels":
		_pass("test_team_get_faction_default",
			"Team.get_faction(UNASSIGNED) defaults to 'angels'")
	else:
		_fail("test_team_get_faction_default",
			"got '%s', expected 'angels'" % faction)


func test_remote_player_set_faction() -> void:
	const RemotePlayer = preload("res://client/scripts/remote_player.gd")
	var rp := Node3D.new()
	rp.set_script(RemotePlayer)
	rp.create(888)
	add_child(rp)
	rp.set_faction("demons")
	var has_mesh := rp.character_model.mesh_instance != null
	rp.queue_free()
	if has_mesh:
		_pass("test_remote_player_set_faction",
			"set_faction('demons') loads D1 model on remote player")
	else:
		_fail("test_remote_player_set_faction",
			"mesh_instance is null after set_faction")


func test_shared_skeleton_compat() -> void:
	var cm_a := CharacterModel.new()
	cm_a.name = "TestA1Skel"
	add_child(cm_a)
	cm_a.setup("angels")

	var cm_d := CharacterModel.new()
	cm_d.name = "TestD1Skel"
	add_child(cm_d)
	cm_d.setup("demons")

	var a_bones := 0
	var d_bones := 0
	if cm_a.skeleton:
		a_bones = cm_a.skeleton.get_bone_count()
	if cm_d.skeleton:
		d_bones = cm_d.skeleton.get_bone_count()

	cm_a.queue_free()
	cm_d.queue_free()

	if a_bones > 0 and a_bones == d_bones:
		_pass("test_shared_skeleton_compat",
			"A1 and D1 share same bone count (%d)" % a_bones)
	else:
		_fail("test_shared_skeleton_compat",
			"A1 bones=%d, D1 bones=%d" % [a_bones, d_bones])
