extends Node

const ServerPlayer = preload("res://server/scripts/server_player.gd")

var server_tick: int = 0
var players: Dictionary = {}
var last_snapshots: Dictionary = {}
var world_node: Node3D

var spawn_points: Array[Vector3] = [
	Vector3(0, 1, 0),
	Vector3(5, 1, 0),
	Vector3(-5, 1, 0),
	Vector3(0, 1, 5),
	Vector3(0, 1, -5),
	Vector3(5, 1, 5),
	Vector3(-5, 1, -5),
	Vector3(5, 1, -5),
	Vector3(-5, 1, 5),
	Vector3(10, 1, 0),
]
var next_spawn := 0


func _ready() -> void:
	Engine.physics_ticks_per_second = NetConstants.TICK_RATE
	process_physics_priority = 1

	world_node = Node3D.new()
	world_node.name = "World"
	add_child(world_node)
	_create_floor()

	var port := NetworkManager.DEFAULT_PORT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()

	var err := NetworkManager.host_server(port)
	if err != OK:
		push_error("Server failed to start on port %d" % port)
		get_tree().quit(1)
		return

	NetworkManager.peer_connected.connect(_on_peer_connected)
	NetworkManager.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_packet.connect(_on_peer_packet)

	print("[Server] Running at %d Hz, listening on port %d" % [NetConstants.TICK_RATE, port])


func _physics_process(_delta: float) -> void:
	server_tick += 1

	if server_tick % 2 == 0:
		_broadcast_snapshots()

	for sp in players.values():
		sp.dequeue_input()


func _on_peer_connected(peer_id: int) -> void:
	var sp = ServerPlayer.new()
	var spawn_pos := spawn_points[next_spawn % spawn_points.size()]
	next_spawn += 1
	sp.create(peer_id, spawn_pos, world_node)
	players[peer_id] = sp
	print("[Server] Player %d spawned at %s (total: %d)" % [peer_id, spawn_pos, players.size()])


func _on_peer_disconnected(peer_id: int) -> void:
	if players.has(peer_id):
		players[peer_id].destroy()
		players.erase(peer_id)
		last_snapshots.erase(peer_id)
	print("[Server] Player %d disconnected (total: %d)" % [peer_id, players.size()])


func _on_peer_packet(peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < NetProtocol.HEADER_SIZE:
		return
	if packet[0] != NetConstants.PROTOCOL_VERSION:
		return

	var msg_type: int = packet[1]
	if msg_type == NetProtocol.MSG_INPUT:
		_handle_input_packet(peer_id, packet)


func _handle_input_packet(peer_id: int, packet: PackedByteArray) -> void:
	if not players.has(peer_id):
		return
	var commands := NetProtocol.unpack_input_packet(packet)
	if commands.is_empty():
		return

	var sp = players[peer_id]
	for i in range(commands.size() - 1, -1, -1):
		var cmd = commands[i]
		if cmd.tick > sp.last_acked_tick:
			sp.queue_input(cmd)


func _broadcast_snapshots() -> void:
	if players.is_empty():
		return

	var states: Array = []
	for sp in players.values():
		states.append(sp.get_snapshot(server_tick))

	for peer_id in players:
		var bases: Dictionary = last_snapshots.get(peer_id, {})
		var packet: PackedByteArray
		if bases.is_empty():
			packet = NetProtocol.pack_snapshot_full(server_tick, states)
		else:
			packet = NetProtocol.pack_snapshot_delta(server_tick, server_tick - 2, states, bases)

		multiplayer.send_bytes(packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
			NetConstants.CHANNEL_SNAPSHOT)

		var new_bases: Dictionary = {}
		for s in states:
			new_bases[s.peer_id] = s.duplicate_state()
		last_snapshots[peer_id] = new_bases


func _create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.1
	world_node.add_child(floor_body)
