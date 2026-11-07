extends Node

const SLC = preload("res://server/scripts/server_lag_comp.gd")
const MC = preload("res://shared/scripts/movement_constants.gd")
const WR = preload("res://shared/scripts/weapon_registry.gd")

var tests_passed := 0
var tests_failed := 0
var results: Array[String] = []


func _ready() -> void:
	print("=== Phase 7 Integration Tests ===")
	print("Cross-cutting: lag comp compat, faction models, weapons, viewmodel, animations")
	print("")

	test_head_bone_matches_lagcomp()
	test_both_factions_load()
	test_skeleton_bone_count_matches()
	test_skeleton_bone_names_match()
	test_anim_tree_active_both_factions()
	test_weapon_attach_both_factions()
	test_weapon_models_on_both_factions()
	test_viewmodel_both_factions()
	test_grenade_models_all_load()
	test_death_anim_both_factions()
	test_duck_blend_both_factions()
	test_all_phase7_glb_files_exist()
	test_ten_player_instantiation()

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


func _make_model(faction: String) -> CharacterModel:
	var cm := CharacterModel.new()
	cm.name = "Test_%s" % faction
	add_child(cm)
	cm.setup(faction)
	return cm


func test_head_bone_matches_lagcomp() -> void:
	var cm := _make_model("angels")
	if not cm.skeleton:
		cm.queue_free()
		_fail("test_head_bone_matches_lagcomp", "no skeleton loaded")
		return
	var head_idx := cm.skeleton.find_bone("head")
	if head_idx < 0:
		cm.queue_free()
		_fail("test_head_bone_matches_lagcomp", "head bone not found")
		return
	var head_rest := cm.skeleton.get_bone_rest(head_idx)
	var head_global_y := _get_bone_global_y(cm.skeleton, head_idx)
	var lagcomp_y: float = SLC.HEAD_STANDING.y
	var diff := absf(head_global_y - lagcomp_y)
	cm.queue_free()
	if diff < 0.05:
		_pass("test_head_bone_matches_lagcomp",
			"head bone y=%.3f vs lagcomp y=%.3f (diff=%.3f)" % [head_global_y, lagcomp_y, diff])
	else:
		_fail("test_head_bone_matches_lagcomp",
			"head bone y=%.3f vs lagcomp HEAD_STANDING y=%.3f (diff=%.3f > 0.05)" % [head_global_y, lagcomp_y, diff])


func _get_bone_global_y(skel: Skeleton3D, bone_idx: int) -> float:
	var y := 0.0
	var idx := bone_idx
	while idx >= 0:
		var rest := skel.get_bone_rest(idx)
		y += rest.origin.y
		idx = skel.get_bone_parent(idx)
	return y


func test_both_factions_load() -> void:
	var cm_a := _make_model("angels")
	var cm_d := _make_model("demons")
	var a_ok := cm_a.skeleton != null and cm_a.mesh_instance != null
	var d_ok := cm_d.skeleton != null and cm_d.mesh_instance != null
	cm_a.queue_free()
	cm_d.queue_free()
	if a_ok and d_ok:
		_pass("test_both_factions_load",
			"both angels and demons models load with skeleton + mesh")
	else:
		_fail("test_both_factions_load",
			"angels=%s demons=%s" % [a_ok, d_ok])


func test_skeleton_bone_count_matches() -> void:
	var cm_a := _make_model("angels")
	var cm_d := _make_model("demons")
	var a_bones := cm_a.skeleton.get_bone_count() if cm_a.skeleton else 0
	var d_bones := cm_d.skeleton.get_bone_count() if cm_d.skeleton else 0
	cm_a.queue_free()
	cm_d.queue_free()
	if a_bones > 0 and a_bones == d_bones:
		_pass("test_skeleton_bone_count_matches",
			"both factions: %d bones" % a_bones)
	else:
		_fail("test_skeleton_bone_count_matches",
			"angels=%d demons=%d" % [a_bones, d_bones])


func test_skeleton_bone_names_match() -> void:
	var cm_a := _make_model("angels")
	var cm_d := _make_model("demons")
	if not cm_a.skeleton or not cm_d.skeleton:
		cm_a.queue_free()
		cm_d.queue_free()
		_fail("test_skeleton_bone_names_match", "skeleton not loaded")
		return
	var mismatches: Array[String] = []
	for i in range(cm_a.skeleton.get_bone_count()):
		var a_name := cm_a.skeleton.get_bone_name(i)
		var d_name := cm_d.skeleton.get_bone_name(i)
		if a_name != d_name:
			mismatches.append("bone %d: %s vs %s" % [i, a_name, d_name])
	cm_a.queue_free()
	cm_d.queue_free()
	if mismatches.is_empty():
		_pass("test_skeleton_bone_names_match",
			"all bone names identical between factions")
	else:
		_fail("test_skeleton_bone_names_match",
			"%d mismatches: %s" % [mismatches.size(), ", ".join(mismatches)])


func test_anim_tree_active_both_factions() -> void:
	var cm_a := _make_model("angels")
	var cm_d := _make_model("demons")
	var a_active := cm_a.anim_tree != null and cm_a.anim_tree.active
	var d_active := cm_d.anim_tree != null and cm_d.anim_tree.active
	cm_a.queue_free()
	cm_d.queue_free()
	if a_active and d_active:
		_pass("test_anim_tree_active_both_factions",
			"AnimationTree active on both factions")
	else:
		_fail("test_anim_tree_active_both_factions",
			"angels=%s demons=%s" % [a_active, d_active])


func test_weapon_attach_both_factions() -> void:
	var cm_a := _make_model("angels")
	var cm_d := _make_model("demons")
	var a_attach := cm_a.weapon_attach != null
	var d_attach := cm_d.weapon_attach != null
	cm_a.queue_free()
	cm_d.queue_free()
	if a_attach and d_attach:
		_pass("test_weapon_attach_both_factions",
			"weapon_attach (hand_r bone) present on both factions")
	else:
		_fail("test_weapon_attach_both_factions",
			"angels=%s demons=%s" % [a_attach, d_attach])


func test_weapon_models_on_both_factions() -> void:
	var weapons := WR.create_all()
	var failed: Array[String] = []
	for faction in ["angels", "demons"]:
		var cm := _make_model(faction)
		for i in range(weapons.size()):
			cm.set_weapon_model(i)
			if cm.current_weapon_visual == null:
				failed.append("%s weapon %d" % [faction, i])
		cm.queue_free()
	if failed.is_empty():
		_pass("test_weapon_models_on_both_factions",
			"all %d weapons attach on both factions" % weapons.size())
	else:
		_fail("test_weapon_models_on_both_factions",
			"missing visuals: %s" % ", ".join(failed))


func test_viewmodel_both_factions() -> void:
	var failed: Array[String] = []
	for faction in ["angels", "demons"]:
		var vm := Viewmodel.new()
		vm.name = "TestVM_%s" % faction
		add_child(vm)
		vm.setup(faction)
		if vm._arms_mesh == null:
			failed.append("%s: no arms mesh" % faction)
		if vm._weapon_visual == null:
			failed.append("%s: no weapon visual" % faction)
		vm.queue_free()
	if failed.is_empty():
		_pass("test_viewmodel_both_factions",
			"viewmodel loads arms + weapon for both factions")
	else:
		_fail("test_viewmodel_both_factions",
			", ".join(failed))


func test_grenade_models_all_load() -> void:
	var GrenadeProjectile = preload("res://shared/scripts/grenade_projectile.gd")
	var paths: Dictionary = GrenadeProjectile.GRENADE_MODEL_PATHS
	var failed: Array[String] = []
	for type_id in paths:
		var path: String = paths[type_id]
		if not ResourceLoader.exists(path):
			failed.append("type %d: %s" % [type_id, path])
		else:
			var scene: PackedScene = load(path)
			if not scene:
				failed.append("type %d: load failed" % type_id)
	if failed.is_empty():
		_pass("test_grenade_models_all_load",
			"all %d grenade model GLBs load" % paths.size())
	else:
		_fail("test_grenade_models_all_load",
			", ".join(failed))


func test_death_anim_both_factions() -> void:
	var failed: Array[String] = []
	for faction in ["angels", "demons"]:
		var cm := _make_model(faction)
		cm.play_death()
		if not cm.is_dead():
			failed.append("%s: not dead after play_death()" % faction)
		if cm.anim_tree and cm.anim_tree.active:
			failed.append("%s: anim_tree still active" % faction)
		cm.queue_free()
	if failed.is_empty():
		_pass("test_death_anim_both_factions",
			"death animation triggers correctly on both factions")
	else:
		_fail("test_death_anim_both_factions",
			", ".join(failed))


func test_duck_blend_both_factions() -> void:
	var failed: Array[String] = []
	for faction in ["angels", "demons"]:
		var cm := _make_model(faction)
		cm.set_ducked(true)
		if cm._target_duck != 1.0:
			failed.append("%s: duck target not set" % faction)
		cm.set_ducked(false)
		if cm._target_duck != 0.0:
			failed.append("%s: unduck target not set" % faction)
		cm.queue_free()
	if failed.is_empty():
		_pass("test_duck_blend_both_factions",
			"duck/unduck targets work on both factions")
	else:
		_fail("test_duck_blend_both_factions",
			", ".join(failed))


func test_all_phase7_glb_files_exist() -> void:
	var paths: Array[String] = []
	for key in CharacterModel.MODEL_PATHS:
		paths.append(CharacterModel.MODEL_PATHS[key])
	for key in Viewmodel.FP_ARMS_PATHS:
		paths.append(Viewmodel.FP_ARMS_PATHS[key])
	for key in CharacterModel.WEAPON_MODEL_PATHS:
		paths.append(CharacterModel.WEAPON_MODEL_PATHS[key])
	for key in Viewmodel.WEAPON_MODEL_PATHS:
		paths.append(Viewmodel.WEAPON_MODEL_PATHS[key])
	var GrenadeProjectile = preload("res://shared/scripts/grenade_projectile.gd")
	for key in GrenadeProjectile.GRENADE_MODEL_PATHS:
		paths.append(GrenadeProjectile.GRENADE_MODEL_PATHS[key])

	var missing: Array[String] = []
	var checked := 0
	for path in paths:
		checked += 1
		if not ResourceLoader.exists(path):
			missing.append(path)
	if missing.is_empty():
		_pass("test_all_phase7_glb_files_exist",
			"all %d GLB asset paths resolve" % checked)
	else:
		_fail("test_all_phase7_glb_files_exist",
			"%d missing: %s" % [missing.size(), ", ".join(missing)])


func test_ten_player_instantiation() -> void:
	var models: Array[CharacterModel] = []
	var start_time := Time.get_ticks_usec()

	for i in range(10):
		var faction := "angels" if i % 2 == 0 else "demons"
		var cm := CharacterModel.new()
		cm.name = "PerfPlayer_%d" % i
		add_child(cm)
		cm.setup(faction)
		cm.set_weapon_model(i % 5)
		models.append(cm)

	var elapsed_us := Time.get_ticks_usec() - start_time
	var elapsed_ms := float(elapsed_us) / 1000.0

	var all_valid := true
	for cm in models:
		if cm.skeleton == null or cm.mesh_instance == null:
			all_valid = false
			break

	for cm in models:
		cm.queue_free()

	if all_valid:
		_pass("test_ten_player_instantiation",
			"10 players (5 angels, 5 demons) instantiated in %.1fms" % elapsed_ms)
	else:
		_fail("test_ten_player_instantiation",
			"some models failed to load")
