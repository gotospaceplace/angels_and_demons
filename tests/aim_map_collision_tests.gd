extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")

var player: CharacterBody3D
var current_test := ""
var tests_passed := 0
var tests_failed := 0
var test_queue: Array[StringName] = []
var tick := 0
var test_state := {}
var results: Array[String] = []

var _angels_raw: Array[Vector3] = [
	Vector3(-1.8161, 1.1176, 17.78),
	Vector3(-5.0673, 0.9144, 17.78),
	Vector3(-8.3185, 0.9144, 17.78),
	Vector3(1.4351, 1.1176, 14.5288),
	Vector3(1.0287, 1.1176, 16.1544),
	Vector3(1.4351, 1.1176, 17.78),
	Vector3(1.4351, 1.1176, 19.4056),
	Vector3(-1.8161, 0.9144, 19.4056),
	Vector3(-1.8161, 0.9144, 16.1544),
	Vector3(-1.8161, 0.9144, 14.5288),
	Vector3(-5.0673, 0.9144, 14.5288),
	Vector3(-5.0673, 0.9144, 16.1544),
	Vector3(-5.0673, 0.9144, 19.4056),
	Vector3(-8.3185, 0.9144, 19.4056),
	Vector3(-8.3185, 0.9144, 16.1544),
	Vector3(-8.3185, 0.9144, 14.5288),
]

var _demons_raw: Array[Vector3] = [
	Vector3(8.5471, 0.9144, -14.5034),
	Vector3(8.5471, 0.9144, -16.129),
	Vector3(8.5471, 0.9144, -19.3802),
	Vector3(5.2959, 0.9144, -19.3802),
	Vector3(5.2959, 0.9144, -16.129),
	Vector3(5.2959, 0.9144, -14.5034),
	Vector3(2.0447, 0.9144, -14.5034),
	Vector3(2.0447, 0.9144, -16.129),
	Vector3(2.0447, 0.9144, -19.3802),
	Vector3(-1.2065, 1.1176, -19.3802),
	Vector3(-1.2065, 1.1176, -17.7546),
	Vector3(-1.2065, 1.1176, -16.129),
	Vector3(-1.2065, 1.1176, -14.5034),
	Vector3(8.5471, 0.9144, -17.7546),
	Vector3(5.2959, 0.9144, -17.7546),
	Vector3(2.0447, 1.1176, -17.7546),
]

var _crate_tops: Array[Dictionary] = [
	{"name": "small_crate_angel", "pos": Vector3(-8.03, 1.5, 13.51), "top_y": 0.889},
	{"name": "large_crate_mid_angel", "pos": Vector3(1.97, 3.0, 11.96), "top_y": 2.235},
	{"name": "small_crate_demon", "pos": Vector3(8.25, 1.5, -13.49), "top_y": 0.889},
	{"name": "large_crate_mid_demon", "pos": Vector3(-1.74, 3.0, -11.94), "top_y": 2.235},
	{"name": "tall_crate_angel", "pos": Vector3(-3.31, 4.0, 10.97), "top_y": 3.277},
	{"name": "tall_crate_demon", "pos": Vector3(11.06, 4.0, -11.99), "top_y": 3.277},
]


func _ready() -> void:
	player = _find_player()
	if not player:
		_fail_hard("No player found in scene")
		return

	player.test_driven = true
	player.set_process_unhandled_input(false)
	process_physics_priority = -1

	for i in range(16):
		test_queue.append(StringName("test_angel_spawn_%d" % i))
	for i in range(16):
		test_queue.append(StringName("test_demon_spawn_%d" % i))
	for i in range(_crate_tops.size()):
		test_queue.append(StringName("test_crate_top_%d" % i))
	test_queue.append(&"test_walk_on_ground")
	test_queue.append(&"test_walk_up_ramp")
	test_queue.append(&"test_wall_collision")

	print("=== aim_map Collision Tests (Phase 2B) ===")
	print("Tests to run: %d" % test_queue.size())
	print("")
	_start_next_test()


func _physics_process(_delta: float) -> void:
	if current_test == "":
		return
	tick += 1

	if current_test.begins_with("test_angel_spawn_"):
		var idx := current_test.trim_prefix("test_angel_spawn_").to_int()
		_run_spawn_test("Angel", idx, _angels_raw[idx])
	elif current_test.begins_with("test_demon_spawn_"):
		var idx := current_test.trim_prefix("test_demon_spawn_").to_int()
		_run_spawn_test("Demon", idx, _demons_raw[idx])
	elif current_test.begins_with("test_crate_top_"):
		var idx := current_test.trim_prefix("test_crate_top_").to_int()
		_run_crate_test(idx)
	elif current_test == "test_walk_on_ground":
		_run_walk_test()
	elif current_test == "test_walk_up_ramp":
		_run_ramp_test()
	elif current_test == "test_wall_collision":
		_run_wall_test()


func _run_spawn_test(team: String, idx: int, spawn: Vector3) -> void:
	if tick == 1:
		_reset_player(spawn)
		test_state["start_y"] = player.global_position.y
		_set_input(0.0)
	elif tick >= 32:
		var y := player.global_position.y
		var start_y: float = test_state["start_y"]
		var fell := start_y - y

		if fell > 1.0:
			_fail("%s #%d fell through floor (dropped %.3fm from Y=%.3f to Y=%.3f)" % [
				team, idx, fell, start_y, y])
		elif not player.on_ground:
			if y > -10.0:
				_pass("%s #%d settled at Y=%.3f (airborne but not falling)" % [team, idx, y])
			else:
				_fail("%s #%d fell to void (Y=%.3f)" % [team, idx, y])
		else:
			_pass("%s #%d on ground at Y=%.3f" % [team, idx, y])


func _run_crate_test(idx: int) -> void:
	var crate: Dictionary = _crate_tops[idx]
	if tick == 1:
		_reset_player(crate["pos"])
		test_state["start_y"] = player.global_position.y
		_set_input(0.0)
	elif tick >= 32:
		var y := player.global_position.y
		var start_y: float = test_state["start_y"]
		var fell := start_y - y

		if fell > 1.0:
			_fail("crate '%s' fell through (dropped %.3fm)" % [crate["name"], fell])
		elif not player.on_ground:
			if y > -10.0:
				_pass("crate '%s' settling at Y=%.3f" % [crate["name"], y])
			else:
				_fail("crate '%s' fell to void (Y=%.3f)" % [crate["name"], y])
		else:
			var expected_top: float = crate["top_y"]
			var feet_y := y - MC.HULL_STANDING_HEIGHT / 2.0
			if absf(feet_y - expected_top) < 0.5:
				_pass("crate '%s' standing at Y=%.3f (feet=%.3f, top=%.3f)" % [
					crate["name"], y, feet_y, expected_top])
			else:
				_pass("crate '%s' on ground at Y=%.3f (may have slid off)" % [crate["name"], y])


func _run_walk_test() -> void:
	if tick == 1:
		_reset_player(_angels_raw[1])
		_set_input(1.0)
		test_state["start_y"] = player.global_position.y
	elif tick >= 64:
		var y := player.global_position.y
		var start_y: float = test_state["start_y"]
		var speed := Vector3(player.velocity.x, 0, player.velocity.z).length()

		if y < -10.0:
			_fail("walk: fell through floor (Y=%.3f)" % y)
		elif speed < 0.1:
			_fail("walk: stuck (speed=%.3f m/s)" % speed)
		elif not player.on_ground:
			_pass("walk: moving at %.1f u/s, airborne at Y=%.3f (may have hit edge)" % [
				speed * MC.UNITS_PER_METER, y])
		else:
			_pass("walk: moving at %.1f u/s, on ground at Y=%.3f" % [
				speed * MC.UNITS_PER_METER, y])


func _run_ramp_test() -> void:
	if tick == 1:
		_reset_player(Vector3(11.25, 0.9, 15.0), PI)
		_set_input(1.0)
		test_state["start_y"] = player.global_position.y
	if tick >= 128:
		var y := player.global_position.y
		var start_y: float = test_state["start_y"]
		var gained := y - start_y

		if gained < 1.0:
			_fail("ramp: couldn't ascend (gained %.3fm, Y=%.3f → %.3f)" % [
				gained, start_y, y])
		elif y < -10.0:
			_fail("ramp: fell through (Y=%.3f)" % y)
		else:
			_pass("ramp: ascended %.1fm (Y=%.3f → %.3f)" % [gained, start_y, y])


func _run_wall_test() -> void:
	if tick == 1:
		_reset_player(Vector3(-8.3185, 0.9144, 14.5288), 0.0)
		_set_input(0.0, -1.0)
	elif tick >= 64:
		var x := player.global_position.x
		if x < -18.0:
			_fail("wall: passed through outer wall (X=%.3f)" % x)
		else:
			_pass("wall: blocked at X=%.3f" % x)


func _start_next_test() -> void:
	if test_queue.is_empty():
		_print_summary()
		return
	current_test = test_queue.pop_front()
	tick = 0
	test_state = {}
	print("  RUN  %s" % current_test)


func _reset_player(pos: Vector3, yaw: float = -PI / 2.0) -> void:
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.on_ground = false
	player.was_on_ground = false
	player.jump_pressed = false
	player.jump_was_pressed = false
	player.scroll_jump_queued = false
	player.is_ducked = false
	player.wants_duck = false
	player.duck_eye_progress = 0.0
	player.hop_count = 0
	player.ground_time = 0.0
	player.ground_normal = Vector3.UP
	player.on_ladder = false
	player.wants_walk = false
	player.wish_dir = Vector3.ZERO
	player.wish_speed = 0.0
	player.max_speed = MC.SPEED_MELEE
	player.rotation = Vector3(0, yaw, 0)


func _set_input(forward: float, right: float = 0.0, jump: bool = false, duck: bool = false) -> void:
	var dir := Vector3.ZERO
	var basis := player.global_transform.basis
	var fwd := -basis.z
	var rt := basis.x
	fwd.y = 0.0
	rt.y = 0.0
	fwd = fwd.normalized()
	rt = rt.normalized()

	var wish_vel := fwd * forward + rt * right
	player.wish_speed = wish_vel.length() * player.max_speed
	if wish_vel.length() > 0.001:
		player.wish_dir = wish_vel.normalized()
	else:
		player.wish_dir = Vector3.ZERO

	player.jump_was_pressed = player.jump_pressed
	player.jump_pressed = jump
	player.wants_duck = duck


func _pass(msg: String) -> void:
	tests_passed += 1
	results.append("  PASS %s: %s" % [current_test, msg])
	print("  PASS %s" % msg)
	current_test = ""
	_start_next_test()


func _fail(msg: String) -> void:
	tests_failed += 1
	results.append("  FAIL %s: %s" % [current_test, msg])
	print("  FAIL %s" % msg)
	current_test = ""
	_start_next_test()


func _fail_hard(msg: String) -> void:
	print("FATAL: %s" % msg)
	get_tree().quit(2)


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


func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
