extends Node

const ServerPlayer = preload("res://server/scripts/server_player.gd")
const ServerLagComp = preload("res://server/scripts/server_lag_comp.gd")
const ServerConsole = preload("res://server/scripts/server_console.gd")
const TestMapScene = preload("res://shared/scenes/mp_testmap.tscn")

var server_tick: int = 0
var players: Dictionary = {}
var world_node: Node3D
var snapshot_bytes_total: int = 0
var snapshot_count: int = 0
var lag_comp: ServerLagComp
var console: Node

var peer_tokens: Dictionary = {}
var disconnected_players: Dictionary = {}
var pending_peers: Dictionary = {}
var next_token: int = 1

const PENDING_TIMEOUT_TICKS := 64

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

	var map := TestMapScene.instantiate()
	map.name = "World"
	add_child(map)
	world_node = map
	if map.spawn_points.size() > 0:
		spawn_points = map.spawn_points

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

	var console_node := Node.new()
	console_node.name = "ServerConsole"
	console_node.set_script(ServerConsole)
	add_child(console_node)
	console = console_node
	console.command_received.connect(_on_console_command)

	print("[Server] Running at %d Hz, listening on port %d" % [NetConstants.TICK_RATE, port])


func _physics_process(_delta: float) -> void:
	server_tick += 1

	_process_pending_peers()
	_process_disconnect_timeouts()

	for sp in players.values():
		sp.dequeue_input(server_tick)

	_process_fire_commands()
	_process_respawns()
	lag_comp.store_tick(server_tick, players)

	if server_tick % 2 == 0:
		_broadcast_snapshots()


func _on_peer_connected(peer_id: int) -> void:
	pending_peers[peer_id] = server_tick
	print("[Server] Peer %d connected, waiting for rejoin or timeout" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	pending_peers.erase(peer_id)
	if players.has(peer_id):
		var sp = players[peer_id]
		var token: int = peer_tokens.get(peer_id, 0)
		if token > 0:
			disconnected_players[token] = {
				"kills": sp.kills,
				"deaths": sp.deaths,
				"disconnect_tick": server_tick,
			}
			print("[Server] Player %d disconnected, state saved (token=%d, K:%d D:%d, timeout=%.0fs)" % [
				peer_id, token, sp.kills, sp.deaths, NetConstants.DISCONNECT_TIMEOUT])
		sp.destroy()
		players.erase(peer_id)
		peer_tokens.erase(peer_id)
	else:
		print("[Server] Peer %d disconnected (was not spawned)" % peer_id)


func _on_peer_packet(peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < NetProtocol.HEADER_SIZE:
		return
	if packet[0] != NetConstants.PROTOCOL_VERSION:
		return

	var msg_type: int = packet[1]
	if msg_type == NetProtocol.MSG_INPUT:
		if pending_peers.has(peer_id):
			_spawn_new_player(peer_id)
		_handle_input_packet(peer_id, packet)
	elif msg_type == NetProtocol.MSG_ADMIN:
		_handle_admin_packet(peer_id, packet)


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

	for cmd in commands:
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


func _handle_admin_packet(peer_id: int, packet: PackedByteArray) -> void:
	if packet.size() < 3:
		return
	var admin_type: int = packet[2]
	if admin_type == NetProtocol.ADMIN_REJOIN:
		if packet.size() < 7:
			return
		var token: int = packet[3] | (packet[4] << 8) | (packet[5] << 16) | (packet[6] << 24)
		if disconnected_players.has(token):
			_restore_player(peer_id, token)
		else:
			_spawn_new_player(peer_id)


func _spawn_new_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	pending_peers.erase(peer_id)

	var token := next_token
	next_token += 1

	var sp = ServerPlayer.new()
	var spawn_pos := spawn_points[next_spawn % spawn_points.size()]
	next_spawn += 1
	sp.create(peer_id, spawn_pos, world_node)
	players[peer_id] = sp
	peer_tokens[peer_id] = token

	var session_packet := NetProtocol.pack_session_event(token)
	multiplayer.send_bytes(session_packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)

	var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
	for pid in players:
		multiplayer.send_bytes(spawn_packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

	print("[Server] New player %d spawned at %s (token=%d, total: %d)" % [
		peer_id, spawn_pos, token, players.size()])


func _restore_player(peer_id: int, token: int) -> void:
	pending_peers.erase(peer_id)

	var saved: Dictionary = disconnected_players[token]
	disconnected_players.erase(token)

	var sp = ServerPlayer.new()
	var spawn_pos := spawn_points[next_spawn % spawn_points.size()]
	next_spawn += 1
	sp.create(peer_id, spawn_pos, world_node)
	sp.kills = saved["kills"]
	sp.deaths = saved["deaths"]
	players[peer_id] = sp
	peer_tokens[peer_id] = token

	var session_packet := NetProtocol.pack_session_event(token)
	multiplayer.send_bytes(session_packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)

	var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
	for pid in players:
		multiplayer.send_bytes(spawn_packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

	print("[Server] Player %d reconnected (token=%d, K:%d D:%d, total: %d)" % [
		peer_id, token, sp.kills, sp.deaths, players.size()])


func _process_pending_peers() -> void:
	var to_spawn: Array = []
	for pid in pending_peers:
		if server_tick - pending_peers[pid] >= PENDING_TIMEOUT_TICKS:
			to_spawn.append(pid)
	for pid in to_spawn:
		_spawn_new_player(pid)


func _process_disconnect_timeouts() -> void:
	var timeout_ticks := int(NetConstants.DISCONNECT_TIMEOUT * float(NetConstants.TICK_RATE))
	var expired: Array = []
	for token in disconnected_players:
		var data: Dictionary = disconnected_players[token]
		if server_tick - data["disconnect_tick"] >= timeout_ticks:
			expired.append(token)
	for token in expired:
		var data: Dictionary = disconnected_players[token]
		disconnected_players.erase(token)
		print("[Server] Disconnected player timed out (token=%d, K:%d D:%d)" % [
			token, data["kills"], data["deaths"]])


func _on_console_command(cmd: String, args: String) -> void:
	match cmd:
		"status":
			_cmd_status()
		"kick":
			_cmd_kick(args)
		"say":
			_cmd_say(args)
		"quit":
			_cmd_quit()
		_:
			print("[Console] Unknown command: %s" % cmd)


func _cmd_status() -> void:
	print("[Console] === Server Status (tick %d) ===" % server_tick)
	print("[Console] Players: %d / %d" % [players.size(), NetConstants.MAX_PLAYERS])
	print("[Console] Pending connections: %d" % pending_peers.size())
	print("[Console] Disconnected (saved): %d" % disconnected_players.size())
	if players.is_empty():
		print("[Console] No players connected")
		return
	for peer_id in players:
		var sp = players[peer_id]
		var ping := 0
		var enet_peer := NetworkManager.peer.get_peer(peer_id)
		if enet_peer:
			ping = int(enet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		var token: int = peer_tokens.get(peer_id, 0)
		print("[Console]   ID:%d  token:%d  K:%d D:%d  HP:%d  ping:%dms%s" % [
			peer_id, token, sp.kills, sp.deaths, sp.hp, ping,
			" (DEAD)" if sp.is_dead else ""])


func _cmd_kick(args: String) -> void:
	if args.is_empty():
		print("[Console] Usage: kick <peer_id>")
		return
	var peer_id := args.strip_edges().to_int()
	if not players.has(peer_id) and not pending_peers.has(peer_id):
		print("[Console] No player with ID %d" % peer_id)
		return
	print("[Console] ADMIN: Kicking player %d" % peer_id)
	NetworkManager.peer.get_peer(peer_id).peer_disconnect_now(0)


func _cmd_say(args: String) -> void:
	if args.is_empty():
		print("[Console] Usage: say <message>")
		return
	print("[Console] ADMIN: Broadcast: %s" % args)
	var packet := NetProtocol.pack_server_msg_event(args)
	for peer_id in players:
		multiplayer.send_bytes(packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)


func _cmd_quit() -> void:
	print("[Console] ADMIN: Server shutting down")
	var msg := NetProtocol.pack_server_msg_event("Server shutting down")
	for peer_id in players:
		multiplayer.send_bytes(msg, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)
	if console:
		console.stop()
	get_tree().quit()


