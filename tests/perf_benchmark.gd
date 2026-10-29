extends Node

const ServerPlayer = preload("res://server/scripts/server_player.gd")
const ServerLagComp = preload("res://server/scripts/server_lag_comp.gd")
const PlayerMovement = preload("res://shared/scripts/player_movement.gd")
const MC = preload("res://shared/scripts/movement_constants.gd")

var world_node: Node3D
var results: Array[String] = []


func _ready() -> void:
	Engine.physics_ticks_per_second = NetConstants.TICK_RATE
	world_node = Node3D.new()
	world_node.name = "BenchWorld"
	add_child(world_node)
	_create_floor()

	print("=== Phase 4 Performance Benchmark ===")
	print("Tick rate: %d Hz (budget: %.2f ms/tick)" % [
		NetConstants.TICK_RATE, 1000.0 / float(NetConstants.TICK_RATE)])
	print("")

	_bench_server_tick(2)
	_bench_server_tick(5)
	_bench_server_tick(10)
	_bench_bandwidth(2)
	_bench_bandwidth(5)
	_bench_bandwidth(10)
	_bench_prediction_replay()
	_bench_lag_comp_rewind(10)

	print("")
	print("=== Summary ===")
	for r in results:
		print(r)
	print("")
	print("Tick budget: %.2f ms (128 Hz)" % (1000.0 / 128.0))
	print("Target: <4 ms server tick at 10 players (50%% headroom)")
	get_tree().quit(0)


func _bench_server_tick(player_count: int) -> void:
	var players: Dictionary = {}
	var lag_comp := ServerLagComp.new()

	for i in range(player_count):
		var sp = ServerPlayer.new()
		sp.create(i + 1, Vector3(float(i) * 3.0, 1.0, 0.0), world_node)
		players[i + 1] = sp
		var cmd := NetInput.create(1, 0b00000001, 90.0, 0.0)
		sp.queue_input(cmd)

	var warmup := 20
	for t in range(warmup):
		for sp in players.values():
			sp.dequeue_input()
			var cmd := NetInput.create(t + 2, 0b00000001, 90.0, 0.0)
			sp.queue_input(cmd)
		lag_comp.store_tick(t, players)

	var iterations := 200
	var start := Time.get_ticks_usec()
	for t in range(iterations):
		var tick := warmup + t
		for sp in players.values():
			sp.dequeue_input()
			var cmd := NetInput.create(tick + 2, 0b00000001, 90.0, 0.0)
			sp.queue_input(cmd)
		lag_comp.store_tick(tick, players)
		# Snapshot generation
		var states: Array = []
		for sp in players.values():
			states.append(sp.get_snapshot(tick))
	var elapsed := Time.get_ticks_usec() - start
	var avg_us := float(elapsed) / float(iterations)
	var avg_ms := avg_us / 1000.0

	for sp in players.values():
		sp.destroy()

	var line := "  Server tick (%d players): %.3f ms/tick (%.1f%% of budget)" % [
		player_count, avg_ms, avg_ms / (1000.0 / 128.0) * 100.0]
	print(line)
	results.append(line)


func _bench_bandwidth(player_count: int) -> void:
	var states: Array = []
	for i in range(player_count):
		var s := NetSnapshot.new()
		s.peer_id = i + 1
		s.tick = 5000
		s.position = Vector3(float(i) * 5.0, 1.0, float(i) * 2.0)
		s.velocity = Vector3(3.0, 0.0, -1.0)
		s.yaw = float(i) * 36.0
		s.hp = 100
		s.armor = 50
		s.weapon_idx = i % 5
		s.ammo_mag = 30
		states.append(s)

	var full_packet := NetProtocol.pack_snapshot_full(5000, states)
	var full_per_client := full_packet.size()

	var base_states: Array = []
	for i in range(player_count):
		var s := NetSnapshot.new()
		s.peer_id = i + 1
		s.tick = 4998
		s.position = Vector3(float(i) * 5.0 + 0.05, 1.0, float(i) * 2.0 + 0.03)
		s.velocity = Vector3(3.0, 0.0, -1.0)
		s.yaw = float(i) * 36.0
		s.hp = 100
		s.armor = 50
		s.weapon_idx = i % 5
		s.ammo_mag = 30
		base_states.append(s)

	var bases: Dictionary = {}
	for s in base_states:
		bases[s.peer_id] = s

	var delta_packet := NetProtocol.pack_snapshot_delta(5000, 4998, states, bases)
	var delta_per_client := delta_packet.size()

	var full_bw := full_per_client * 64 * player_count
	var delta_bw := delta_per_client * 64 * player_count
	var line := "  Bandwidth (%d players): full=%d B/snap (%.1f KB/s), delta=%d B/snap (%.1f KB/s)" % [
		player_count, full_per_client, float(full_bw) / 1024.0,
		delta_per_client, float(delta_bw) / 1024.0]
	print(line)
	results.append(line)


func _bench_prediction_replay() -> void:
	var body := PlayerMovement.new()
	body.name = "PredictionBench"
	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = MC.HULL_STANDING_HEIGHT
	collision.shape = capsule
	body.add_child(collision)
	var head_node := Node3D.new()
	head_node.name = "Head"
	head_node.position.y = MC.VIEW_OFFSET_STANDING
	body.add_child(head_node)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = false
	head_node.add_child(cam)
	body.position = Vector3(0, 1, 0)
	body.test_driven = true
	world_node.add_child(body)

	var inputs: Array = []
	for i in range(NetConstants.INPUT_BUFFER_SIZE):
		inputs.append(NetInput.create(i + 1, 0b00000001, 90.0 + float(i) * 0.1, 0.0))

	var iterations := 50
	var start := Time.get_ticks_usec()
	for _iter in range(iterations):
		body.global_position = Vector3(0, 1, 0)
		body.velocity = Vector3.ZERO
		for cmd in inputs:
			body.apply_network_input(cmd.yaw, cmd.pitch,
				cmd.has_button(NetInput.BIT_FORWARD), cmd.has_button(NetInput.BIT_BACK),
				cmd.has_button(NetInput.BIT_LEFT), cmd.has_button(NetInput.BIT_RIGHT),
				cmd.has_button(NetInput.BIT_JUMP), cmd.has_button(NetInput.BIT_DUCK))
			body.simulate_tick(NetConstants.TICK_INTERVAL)
	var elapsed := Time.get_ticks_usec() - start
	var avg_us := float(elapsed) / float(iterations)

	body.queue_free()

	var line := "  Prediction replay (%d inputs): %.3f ms (worst-case reconciliation)" % [
		NetConstants.INPUT_BUFFER_SIZE, avg_us / 1000.0]
	print(line)
	results.append(line)


func _bench_lag_comp_rewind(player_count: int) -> void:
	var lag_comp := ServerLagComp.new()
	var players: Dictionary = {}

	for i in range(player_count):
		var sp = ServerPlayer.new()
		sp.create(i + 1, Vector3(float(i) * 3.0, 1.0, 0.0), world_node)
		players[i + 1] = sp

	for t in range(ServerLagComp.HISTORY_SIZE):
		for sp in players.values():
			sp.body.global_position.x += 0.05
		lag_comp.store_tick(1000 + t, players)

	var space := world_node.get_world_3d().direct_space_state
	var iterations := 200
	var shooter_sp = players[1]
	var cmd := NetInput.create(1000 + ServerLagComp.HISTORY_SIZE - NetConstants.MAX_REWIND_TICKS,
		0, 90.0, 0.0)
	cmd.set_button(NetInput.BIT_FIRE, true)

	var start := Time.get_ticks_usec()
	for _iter in range(iterations):
		lag_comp.process_fire(1, cmd, 1000 + ServerLagComp.HISTORY_SIZE, players, space)
	var elapsed := Time.get_ticks_usec() - start
	var avg_us := float(elapsed) / float(iterations)

	for sp in players.values():
		sp.destroy()

	var line := "  Lag comp rewind (%d players, %d tick window): %.3f ms/fire" % [
		player_count, NetConstants.MAX_REWIND_TICKS, avg_us / 1000.0]
	print(line)
	results.append(line)


func _create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "BenchFloor"
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world_node.add_child(floor_body)
