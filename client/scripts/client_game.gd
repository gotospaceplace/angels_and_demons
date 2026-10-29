extends Node

var client_tick: int = 0
var server_tick: int = 0
var tick_synced: bool = false

var input_buffer: Array = []
var recent_inputs: Array = []

var local_player: CharacterBody3D
var snapshot_buffer: Array = []

var snapshots_received: int = 0


func _ready() -> void:
	Engine.physics_ticks_per_second = NetConstants.TICK_RATE
	process_physics_priority = -1

	var server_address := "127.0.0.1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--join="):
			server_address = arg.get_slice("=", 1)

	multiplayer.peer_packet.connect(_on_peer_packet)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var player := get_node_or_null("Player")
	if player:
		set_local_player(player)

	var err := NetworkManager.join_server(server_address)
	if err != OK:
		push_error("Failed to connect to %s" % server_address)
		get_tree().quit(1)


func _on_connected() -> void:
	print("[Client] Connected to server (peer ID: %d)" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	print("[Client] Connection failed")
	get_tree().quit(1)


func _on_server_disconnected() -> void:
	print("[Client] Server disconnected")


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	client_tick += 1

	var cmd := _sample_input()
	_store_input(cmd)

	if client_tick % 2 == 0:
		_send_input()


func _sample_input() -> NetInput:
	var cmd := NetInput.new()
	cmd.tick = client_tick

	if local_player:
		cmd.yaw = fposmod(rad_to_deg(local_player.rotation.y), 360.0)
		cmd.pitch = rad_to_deg(local_player.get_node("Head").rotation.x)

	cmd.set_button(NetInput.BIT_FORWARD, Input.is_action_pressed("move_forward"))
	cmd.set_button(NetInput.BIT_BACK, Input.is_action_pressed("move_backward"))
	cmd.set_button(NetInput.BIT_LEFT, Input.is_action_pressed("move_left"))
	cmd.set_button(NetInput.BIT_RIGHT, Input.is_action_pressed("move_right"))
	cmd.set_button(NetInput.BIT_JUMP, Input.is_action_pressed("jump"))
	cmd.set_button(NetInput.BIT_DUCK, Input.is_action_pressed("duck"))
	cmd.set_button(NetInput.BIT_FIRE, Input.is_action_pressed("fire"))
	cmd.set_button(NetInput.BIT_FIRE2, Input.is_action_pressed("fire_secondary"))
	cmd.set_button(NetInput.BIT_RELOAD, Input.is_action_pressed("reload"))

	return cmd


func _store_input(cmd: NetInput) -> void:
	input_buffer.append(cmd)
	if input_buffer.size() > NetConstants.INPUT_BUFFER_SIZE:
		input_buffer.pop_front()

	recent_inputs.append(cmd)
	if recent_inputs.size() > NetConstants.INPUT_REDUNDANCY:
		recent_inputs.pop_front()


func _send_input() -> void:
	if recent_inputs.is_empty():
		return
	var packet := NetProtocol.pack_input_packet(recent_inputs)
	multiplayer.send_bytes(packet, 1,
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
		NetConstants.CHANNEL_INPUT)


func _on_peer_packet(_peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < NetProtocol.HEADER_SIZE:
		return
	if packet[0] != NetConstants.PROTOCOL_VERSION:
		return

	var msg_type: int = packet[1]
	if msg_type == NetProtocol.MSG_SNAPSHOT:
		_handle_snapshot(packet)


func _handle_snapshot(packet: PackedByteArray) -> void:
	var bases: Dictionary = {}
	if snapshot_buffer.size() > 0:
		var last: Dictionary = snapshot_buffer[snapshot_buffer.size() - 1]
		for s in last["states"]:
			bases[s.peer_id] = s

	var result := NetProtocol.unpack_snapshot(packet, bases)
	if result["states"].is_empty():
		return

	snapshot_buffer.append(result)
	if snapshot_buffer.size() > NetConstants.SNAPSHOT_BUFFER_SIZE:
		snapshot_buffer.pop_front()

	server_tick = result["tick"]
	snapshots_received += 1

	if not tick_synced:
		client_tick = server_tick
		tick_synced = true
		print("[Client] Tick synced to server: %d" % server_tick)

	if snapshots_received % 64 == 0:
		print("[Client] Snapshot %d: tick=%d players=%d" % [
			snapshots_received, server_tick, result["states"].size()])


func set_local_player(player: CharacterBody3D) -> void:
	local_player = player
