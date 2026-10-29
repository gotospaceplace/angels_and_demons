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
