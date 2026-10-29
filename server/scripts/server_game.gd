extends Node

const ServerPlayer = preload("res://server/scripts/server_player.gd")
const ServerLagComp = preload("res://server/scripts/server_lag_comp.gd")

var server_tick: int = 0
var players: Dictionary = {}
var world_node: Node3D
var snapshot_bytes_total: int = 0
var snapshot_count: int = 0
var lag_comp: ServerLagComp

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

	lag_comp = ServerLagComp.new()

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

	for sp in players.values():
		sp.dequeue_input()

	_process_fire_commands()
	_process_respawns()
	lag_comp.store_tick(server_tick, players)

	if server_tick % 2 == 0:
		_broadcast_snapshots()


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
	var result := NetProtocol.unpack_input_packet(packet)
	var commands: Array = result["commands"]
	if commands.is_empty():
		return

	var sp = players[peer_id]
	var ack_tick: int = result["ack_tick"]
	if ack_tick > sp.acked_snapshot_tick:
		sp.acked_snapshot_tick = ack_tick

	for i in range(commands.size() - 1, -1, -1):
		var cmd = commands[i]
		if cmd.tick > sp.last_acked_tick:
			sp.queue_input(cmd)


func _process_fire_commands() -> void:
	if players.is_empty():
		return
	var space := world_node.get_world_3d().direct_space_state

	for peer_id in players:
		var sp = players[peer_id]
		if sp.is_dead:
			sp.fire_pressed = false
			continue

		var cmd: NetInput = sp.last_input
		var wants_fire: bool = cmd.has_button(NetInput.BIT_FIRE)

		var should_fire := false
		var weapon = lag_comp.get_weapon(sp.weapon_idx)

		if weapon.is_melee:
			if wants_fire and not sp.fire_pressed and server_tick >= sp.next_fire_tick:
				should_fire = true
		elif weapon.is_automatic:
			if wants_fire and server_tick >= sp.next_fire_tick and sp.ammo_mag > 0:
				should_fire = true
		else:
			if wants_fire and not sp.fire_pressed and server_tick >= sp.next_fire_tick and sp.ammo_mag > 0:
				should_fire = true

		sp.fire_pressed = wants_fire

		if not should_fire:
			continue

		if not weapon.is_melee:
			sp.ammo_mag -= 1

		sp.next_fire_tick = server_tick + maxi(1, int(weapon.cycle_time * float(NetConstants.TICK_RATE)))

		var hit := lag_comp.process_fire(peer_id, cmd, server_tick, players, space)
		if hit.is_empty():
			continue

		var victim_id: int = hit["victim_id"]
		if not players.has(victim_id):
			continue
		var victim_sp = players[victim_id]
		victim_sp.take_damage(hit["damage"])

		var hit_packet := NetProtocol.pack_hit_event(
			victim_id, int(hit["damage"]), hit["headshot"])
		multiplayer.send_bytes(hit_packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

		if victim_sp.is_dead:
			victim_sp.die(server_tick)
			sp.kills += 1
			var kill_packet := NetProtocol.pack_kill_event(
				peer_id, victim_id, sp.weapon_idx, hit["headshot"])
			for pid in players:
				multiplayer.send_bytes(kill_packet, pid,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE,
					NetConstants.CHANNEL_EVENTS)
			print("[Server] KILL: Player %d → Player %d (%s, dmg=%.1f) [K:%d D:%d]" % [
				peer_id, victim_id, hit["hitgroup"], hit["damage"],
				sp.kills, victim_sp.deaths])


func _process_respawns() -> void:
	for peer_id in players:
		var sp = players[peer_id]
		if not sp.is_dead:
			continue
		if sp.respawn_tick <= 0 or server_tick < sp.respawn_tick:
			continue

		var spawn_pos := spawn_points[randi() % spawn_points.size()]
		sp.respawn(spawn_pos)

		var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
		for pid in players:
			multiplayer.send_bytes(spawn_packet, pid,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetConstants.CHANNEL_EVENTS)
		print("[Server] Player %d respawned at %s" % [peer_id, spawn_pos])


func _broadcast_snapshots() -> void:
	if players.is_empty():
		return

	var states: Array = []
	for sp in players.values():
		states.append(sp.get_snapshot(server_tick))

	var broadcast_bytes := 0
	for peer_id in players:
		var sp = players[peer_id]
		var bases: Dictionary = sp.get_acked_bases()
		var packet: PackedByteArray
		if bases.is_empty():
			packet = NetProtocol.pack_snapshot_full(server_tick, states)
		else:
			packet = NetProtocol.pack_snapshot_delta(server_tick, sp.acked_snapshot_tick, states, bases)

		multiplayer.send_bytes(packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED,
			NetConstants.CHANNEL_SNAPSHOT)
		broadcast_bytes += packet.size()

		sp.store_snapshot(server_tick, states)

	snapshot_bytes_total += broadcast_bytes
	snapshot_count += 1
	if snapshot_count % 128 == 0:
		var avg_bytes := snapshot_bytes_total / snapshot_count
		var bw_kbps := float(snapshot_bytes_total) / (float(snapshot_count) / 64.0) / 1024.0
		print("[Server] Snapshot stats: %d players, avg %d bytes/broadcast, %.1f KB/s total" % [
			players.size(), avg_bytes, bw_kbps])
		snapshot_bytes_total = 0
		snapshot_count = 0


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
