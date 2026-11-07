extends Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--test" in args:
		print("EntryPoint: launching movement test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/test_scene.tscn")
		return
	if "--test-combat" in args:
		print("EntryPoint: launching combat test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/combat_test_scene.tscn")
		return
	if "--test-network" in args:
		print("EntryPoint: launching network test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/network_test_scene.tscn")
		return
	if "--validate-scripts" in args:
		print("EntryPoint: launching script validator")
		get_tree().change_scene_to_file.call_deferred("res://tests/script_validator_scene.tscn")
		return
	if "--test-lagcomp" in args:
		print("EntryPoint: launching lag comp headshot tests")
		get_tree().change_scene_to_file.call_deferred("res://tests/lag_comp_test_scene.tscn")
		return
	if "--test-validation" in args:
		print("EntryPoint: launching validation test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/validation_test_scene.tscn")
		return
	if "--test-economy" in args:
		print("EntryPoint: launching economy test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/economy_test_scene.tscn")
		return
	if "--test-round" in args:
		print("EntryPoint: launching round lifecycle test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/round_lifecycle_test_scene.tscn")
		return
	if "--test-objective" in args:
		print("EntryPoint: launching portal objective test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/objective_test_scene.tscn")
		return
	if "--test-spawn" in args:
		print("EntryPoint: launching spawn system test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/spawn_test_scene.tscn")
		return
	if "--test-buymenu" in args:
		print("EntryPoint: launching buy menu test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/buy_menu_test_scene.tscn")
		return
	if "--test-hud" in args:
		print("EntryPoint: launching HUD test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/hud_test_scene.tscn")
		return
	if "--test-match" in args:
		print("EntryPoint: launching consolidated match test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/match_test_scene.tscn")
		return
	if "--test-deathreport" in args:
		print("EntryPoint: launching death report test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/death_report_test_scene.tscn")
		return
	if "--test-killfeed" in args:
		print("EntryPoint: launching kill feed test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/kill_feed_test_scene.tscn")
		return
	if "--test-roundicon" in args:
		print("EntryPoint: launching round icon test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/round_icon_test_scene.tscn")
		return
	if "--test-ffa" in args:
		print("EntryPoint: launching FFA scoreboard test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/ffa_scoreboard_test_scene.tscn")
		return
	if "--test-tdm" in args:
		print("EntryPoint: launching TDM scoreboard test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/tdm_scoreboard_test_scene.tscn")
		return
	if "--test-casual" in args:
		print("EntryPoint: launching casual scoreboard test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/casual_scoreboard_test_scene.tscn")
		return
	if "--test-keybindings" in args:
		print("EntryPoint: launching key bindings test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/key_bindings_test_scene.tscn")
		return
	if "--test-aimmap" in args:
		print("EntryPoint: launching aim_map collision test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/aim_map_collision_test_scene.tscn")
		return
	if "--test-combatanim" in args:
		print("EntryPoint: launching combat animation test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/combat_anim_test_scene.tscn")
		return
	if "--test-weaponmodel" in args:
		print("EntryPoint: launching weapon model test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/weapon_model_test_scene.tscn")
		return
	if "--test-viewmodel" in args:
		print("EntryPoint: launching viewmodel test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/viewmodel_test_scene.tscn")
		return
	if "--test-grenademodel" in args:
		print("EntryPoint: launching grenade model test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/grenade_model_test_scene.tscn")
		return
	if "--test-deathanim" in args:
		print("EntryPoint: launching death animation test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/death_anim_test_scene.tscn")
		return
	if "--test-d1brute" in args:
		print("EntryPoint: launching D1 Brute character test runner")
		get_tree().change_scene_to_file.call_deferred("res://tests/d1_brute_test_scene.tscn")
		return
	if "--bench" in args:
		print("EntryPoint: launching performance benchmark")
		get_tree().change_scene_to_file.call_deferred("res://tests/perf_benchmark_scene.tscn")
		return
	if "--play" in args:
		print("EntryPoint: launching play test")
		get_tree().change_scene_to_file.call_deferred("res://shared/scenes/play_test.tscn")
		return
	if "--host" in args:
		print("EntryPoint: starting multiplayer server")
		get_tree().change_scene_to_file.call_deferred("res://server/scenes/server_main.tscn")
		return
	for arg in args:
		if arg.begins_with("--join"):
			print("EntryPoint: joining as client")
			get_tree().change_scene_to_file.call_deferred("res://client/scenes/mp_client.tscn")
			return

	var is_server := OS.has_feature("dedicated_server")
	print("EntryPoint: dedicated_server=%s" % is_server)
	if is_server:
		get_tree().change_scene_to_file.call_deferred("res://server/scenes/server_main.tscn")
	else:
		get_tree().change_scene_to_file.call_deferred("res://client/scenes/main_menu.tscn")
