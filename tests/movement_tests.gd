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

func _ready() -> void:
	player = _find_player()
	if not player:
		_fail_hard("No player found in scene")
		return

	player.test_driven = true
	player.set_process_unhandled_input(false)

	# Process before the player so _set_input() runs before player's _physics_process
	process_physics_priority = -1

	test_queue = [
		&"test_ground_speed",
		&"test_ground_speed_clamp",
		&"test_jump_height",
		&"test_friction_decel",
		&"test_air_acceleration",
		&"test_bhop_preserves_speed",
		&"test_bhop_degradation",
		&"test_step_up",
		&"test_duck_hull_shrink",
	]

	print("=== Movement Regression Tests ===")
	print("Tests to run: %d" % test_queue.size())
	print("")
	_start_next_test()

func _physics_process(_delta: float) -> void:
	if current_test == "":
		return
	tick += 1
	call(current_test)

func _start_next_test() -> void:
	if test_queue.is_empty():
		_print_summary()
		return

	current_test = test_queue.pop_front()
	tick = 0
	test_state = {}
	_reset_player(Vector3(-8, 1.0, 4))
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
	player.wish_dir = Vector3.ZERO
	player.wish_speed = 0.0
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

func _h_speed() -> float:
	return Vector3(player.velocity.x, 0, player.velocity.z).length()

func _h_speed_gsrc() -> float:
	return _h_speed() * MC.UNITS_PER_METER

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

# --- Tests ---

func test_ground_speed() -> void:
	# Walk forward for 128 ticks (1 second at 128 Hz), check speed reaches ~250 u/s
	_set_input(1.0)

	if tick >= 128:
		var speed := _h_speed_gsrc()
		if absf(speed - 250.0) < 5.0:
			_pass("ground speed %.1f u/s (expected ~250)" % speed)
		else:
			_fail("ground speed %.1f u/s, expected ~250" % speed)

func test_ground_speed_clamp() -> void:
	# Set velocity above clamp, walk one tick, check it gets clamped
	if tick == 1:
		player.velocity = -player.global_transform.basis.z * 10.0  # ~394 u/s
		_set_input(1.0)
	elif tick == 5:
		var speed := _h_speed_gsrc()
		if speed <= 255.0:
			_pass("clamped to %.1f u/s (limit 250)" % speed)
		else:
			_fail("speed %.1f u/s, should be clamped to ~250" % speed)

func test_jump_height() -> void:
	# Wait for ground, then jump, track peak
	if tick < 20:
		_set_input(0.0)
		return

	if not test_state.has("jumped"):
		if player.on_ground:
			test_state["jumped"] = true
			test_state["start_y"] = player.global_position.y
			test_state["peak_y"] = player.global_position.y
			_set_input(0.0, 0.0, true)
		return

	_set_input(0.0, 0.0, false)
	test_state["peak_y"] = maxf(test_state["peak_y"], player.global_position.y)

	if test_state.has("was_airborne") and player.on_ground:
		var height: float = test_state["peak_y"] - test_state["start_y"]
		# GoldSrc standing jump: ~1.143m (45 units)
		if absf(height - 1.143) < 0.08:
			_pass("jump height %.3fm (expected ~1.143)" % height)
		else:
			_fail("jump height %.3fm, expected ~1.143" % height)
		return

	if not player.on_ground:
		test_state["was_airborne"] = true

	if tick > 400:
		_fail("timed out waiting for landing")

func test_friction_decel() -> void:
	# Accelerate to full speed, then stop inputting and measure deceleration
	if tick < 128:
		_set_input(1.0)
		return

	if tick == 128:
		test_state["speed_at_stop"] = _h_speed_gsrc()
		_set_input(0.0)
		return

	_set_input(0.0)

	if tick == 128 + 32:
		var speed_now := _h_speed_gsrc()
		var speed_before: float = test_state["speed_at_stop"]
		var lost := speed_before - speed_now
		# With friction=4, stopspeed=75, at 250 u/s:
		# drop per second = max(speed, stopspeed) * friction = 250 * 4 = 1000 u/s²
		# Over 32 ticks (0.25s): ~250 u/s loss
		# Player should lose significant speed
		if lost > 100.0:
			_pass("friction lost %.0f u/s in 0.25s (from %.0f)" % [lost, speed_before])
		else:
			_fail("friction only lost %.0f u/s in 0.25s (from %.0f)" % [lost, speed_before])

func test_air_acceleration() -> void:
	# Jump while strafing, verify some air speed gain
	if tick < 20:
		_set_input(0.0)
		return

	if not test_state.has("jumped"):
		if player.on_ground:
			test_state["jumped"] = true
			test_state["pre_jump_speed"] = _h_speed_gsrc()
			_set_input(0.0, 0.0, true)
		return

	if tick < 30:
		_set_input(0.0, 0.0, false)
		return

	# Now strafe in the air
	if not test_state.has("strafe_start"):
		test_state["strafe_start"] = _h_speed_gsrc()
		test_state["strafe_tick"] = tick

	_set_input(1.0, 0.0, false)

	if tick - int(test_state["strafe_tick"]) >= 64:
		var gained := _h_speed_gsrc() - float(test_state["strafe_start"])
		if gained > 5.0:
			_pass("air accel gained %.1f u/s over 0.5s" % gained)
		else:
			_fail("air accel only gained %.1f u/s" % gained)

func test_bhop_preserves_speed() -> void:
	if tick < 128:
		_set_input(1.0)
		return

	if not test_state.has("first_jump"):
		if player.on_ground:
			test_state["first_jump"] = true
			test_state["speed_before"] = _h_speed_gsrc()
			_set_input(1.0, 0.0, true)
		return

	if not test_state.has("first_airborne"):
		if not player.on_ground:
			test_state["first_airborne"] = true
		# Release jump so we can re-press
		_set_input(1.0, 0.0, false)
		return

	if not test_state.has("hold_jump"):
		# Now hold jump so it's pressed when we land (scroll_jump style)
		test_state["hold_jump"] = true
		player.scroll_jump_queued = true
		_set_input(1.0, 0.0, false)
		return

	if not test_state.has("landed"):
		# Keep scroll jump queued every tick until landing
		player.scroll_jump_queued = true
		_set_input(1.0, 0.0, false)
		if player.on_ground:
			test_state["landed"] = true
		return

	if not test_state.has("second_airborne"):
		if not player.on_ground:
			test_state["second_airborne"] = true
			var speed_now := _h_speed_gsrc()
			var speed_before: float = test_state["speed_before"]
			if speed_now >= speed_before * 0.85:
				_pass("bhop preserved speed: %.0f -> %.0f u/s" % [speed_before, speed_now])
			else:
				_fail("bhop lost too much: %.0f -> %.0f u/s" % [speed_before, speed_now])
			return
		_set_input(1.0, 0.0, false)
		return

	if tick > 600:
		_fail("timed out")

func test_bhop_degradation() -> void:
	# Chain many hops — after free hops, speed should degrade
	if tick < 128:
		_set_input(1.0)
		return

	if not test_state.has("hop_num"):
		test_state["hop_num"] = 0
		test_state["was_air"] = false
		test_state["initial_speed"] = _h_speed_gsrc()

	# Continuously try to jump every time we land
	if player.on_ground:
		if test_state["was_air"]:
			test_state["hop_num"] = int(test_state["hop_num"]) + 1
			test_state["was_air"] = false

		_set_input(1.0, 0.0, true)

		if int(test_state["hop_num"]) >= 6:
			var speed_now := _h_speed_gsrc()
			var initial: float = test_state["initial_speed"]
			# After 6 hops (4 past free hops), degradation should kick in
			if speed_now < initial * 0.95:
				_pass("degraded after 6 hops: %.0f -> %.0f u/s" % [initial, speed_now])
			else:
				_fail("no degradation after 6 hops: %.0f -> %.0f u/s" % [initial, speed_now])
			return
	else:
		test_state["was_air"] = true
		_set_input(1.0, 0.0, false)

	if tick > 1500:
		_fail("timed out after %d hops" % int(test_state.get("hop_num", 0)))

func test_step_up() -> void:
	# Walk toward the 0.4m step obstacle at x=3 (StaticBody3D)
	if tick == 1:
		_reset_player(Vector3(1.0, 1.0, 0.0))
	if tick < 20:
		_set_input(0.0)
		return

	if not test_state.has("start_y"):
		if player.on_ground:
			test_state["start_y"] = player.global_position.y
			_set_input(1.0)
		return

	_set_input(1.0)

	if tick > 200:
		var dy: float = player.global_position.y - float(test_state["start_y"])
		# Step obstacle: 0.4m tall at x=3, should be auto-stepped
		if dy > 0.2:
			_pass("stepped up %.3fm" % dy)
		elif player.global_position.x > 4.0:
			_pass("walked past step (collision not hit or stepped smoothly)")
		else:
			_fail("stuck at step (dy=%.3f, x=%.1f)" % [dy, player.global_position.x])

func test_duck_hull_shrink() -> void:
	# Duck and verify the collision shape height changes
	if tick < 20:
		_set_input(0.0)
		return

	if not test_state.has("ducked"):
		if player.on_ground:
			test_state["ducked"] = true
			_set_input(0.0, 0.0, false, true)
		return

	_set_input(0.0, 0.0, false, true)

	if tick > 40:
		var capsule: CapsuleShape3D = player.get_node("PlayerCollision").shape
		var expected := MC.HULL_DUCKING_HEIGHT
		if absf(capsule.height - expected) < 0.01:
			_pass("ducked hull height %.3f (expected %.3f)" % [capsule.height, expected])
		else:
			_fail("ducked hull height %.3f, expected %.3f" % [capsule.height, expected])

func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
