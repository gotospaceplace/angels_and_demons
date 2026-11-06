extends Node

const MC = preload("res://shared/scripts/movement_constants.gd")
const WC = preload("res://shared/scripts/weapon_constants.gd")
const ServerPlayer = preload("res://server/scripts/server_player.gd")
const ServerLagComp = preload("res://server/scripts/server_lag_comp.gd")
const ServerConsole = preload("res://server/scripts/server_console.gd")
const MapScene = preload("res://shared/scenes/map_dm_aim.tscn")

var server_tick: int = 0
var players: Dictionary = {}
var world_node: Node3D
var snapshot_bytes_total: int = 0
var snapshot_count: int = 0
var lag_comp: ServerLagComp
var console: Node
var plugin_manager: PluginManager

var peer_tokens: Dictionary = {}
var disconnected_players: Dictionary = {}
var pending_peers: Dictionary = {}
var next_token: int = 1
var _use_state: Dictionary = {}
var damage_log: Array = []

var active_grenades: Array = []
var next_grenade_id: int = 1

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

	var map := MapScene.instantiate()
	map.name = "World"
	add_child(map)
	world_node = map
	if map.spawn_points.size() > 0:
		spawn_points = map.spawn_points

	var port := NetworkManager.DEFAULT_PORT
	var mode_name := "deathmatch"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = arg.get_slice("=", 1).to_int()
		elif arg.begins_with("--mode="):
			mode_name = arg.get_slice("=", 1)

	lag_comp = ServerLagComp.new()

	_init_plugins(mode_name)
	plugin_manager.plugin_event.connect(_on_plugin_event)

	if map.get("angels_spawns") and map.get("demons_spawns"):
		plugin_manager.set_map_spawns(map.angels_spawns, map.demons_spawns)
	if map.get("portal_sites"):
		plugin_manager.set_map_portal_sites(map.portal_sites)

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

	print("[Server] Running at %d Hz, listening on port %d, mode: %s" % [
		NetConstants.TICK_RATE, port, mode_name])


func _init_plugins(mode_name: String) -> void:
	plugin_manager = PluginManager.new()

	plugin_manager.load_plugin(PlatformStats.new())
	plugin_manager.load_plugin(PlatformAnticheat.new())
	plugin_manager.load_plugin(PlatformReporting.new())

	var mode_plugin := _create_mode_plugin(mode_name)
	plugin_manager.load_plugin(mode_plugin)
	plugin_manager.load_plugin(PluginChat.new())


func _physics_process(delta: float) -> void:
	server_tick += 1

	_process_pending_peers()
	_process_disconnect_timeouts()

	for sp in players.values():
		sp.dequeue_input(server_tick)

	_process_fire_commands()
	_process_respawns()
	_process_use_commands(delta)
	_process_grenades(delta)
	lag_comp.store_tick(server_tick, players)

	plugin_manager.dispatch_on_tick(server_tick, delta)

	if server_tick % 2 == 0:
		_broadcast_snapshots()


func _on_peer_connected(peer_id: int) -> void:
	pending_peers[peer_id] = server_tick
	print("[Server] Peer %d connected, waiting for rejoin or timeout" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	pending_peers.erase(peer_id)
	if players.has(peer_id):
		plugin_manager.dispatch_on_player_disconnect(peer_id)
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
		var wants_fire2: bool = cmd.has_button(NetInput.BIT_FIRE2)

		if sp.is_reloading:
			sp.fire_pressed = wants_fire
			sp.fire2_pressed = wants_fire2
			continue

		var should_fire := false
		var is_stab := false
		var weapon = lag_comp.get_weapon(sp.weapon_idx)

		if weapon.is_melee:
			if wants_fire2 and not sp.fire2_pressed and server_tick >= sp.next_fire_tick:
				should_fire = true
				is_stab = true
			elif wants_fire and not sp.fire_pressed and server_tick >= sp.next_fire_tick:
				should_fire = true
		elif weapon.is_automatic:
			if wants_fire and server_tick >= sp.next_fire_tick and sp.ammo_mag > 0:
				should_fire = true
		else:
			if wants_fire and not sp.fire_pressed and server_tick >= sp.next_fire_tick and sp.ammo_mag > 0:
				should_fire = true

		sp.fire_pressed = wants_fire
		sp.fire2_pressed = wants_fire2

		if not should_fire:
			continue

		if not plugin_manager.dispatch_can_player_fire(peer_id):
			continue

		if not weapon.is_melee:
			sp.ammo_mag -= 1
			if sp.ammo_mag <= 0:
				sp.start_reload(server_tick)

		var cycle: float = weapon.stab_cycle_time if is_stab else weapon.cycle_time
		sp.next_fire_tick = server_tick + maxi(1, int(cycle * float(NetConstants.TICK_RATE)))

		var hit := lag_comp.process_fire(peer_id, cmd, server_tick, players, space, is_stab)
		if hit.is_empty():
			continue

		var victim_id: int = hit["victim_id"]
		if not players.has(victim_id):
			continue
		var victim_sp = players[victim_id]

		if victim_sp.is_dead:
			continue

		var final_damage: float = plugin_manager.dispatch_on_player_damage(
			peer_id, victim_id, hit["damage"], sp.weapon_idx, hit["hitgroup"])
		if final_damage <= 0.0:
			continue
		victim_sp.take_damage(final_damage)

		damage_log.append({
			"attacker": peer_id,
			"victim": victim_id,
			"damage": int(ceilf(final_damage)),
			"weapon": sp.weapon_idx,
			"headshot": hit["headshot"],
		})

		var hit_packet := NetProtocol.pack_hit_event(
			victim_id, int(final_damage), hit["headshot"])
		multiplayer.send_bytes(hit_packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

		if victim_sp.is_dead:
			victim_sp.die(server_tick)
			sp.kills += 1
			plugin_manager.last_death_position = victim_sp.body.global_position
			plugin_manager.dispatch_on_player_kill(peer_id, victim_id, sp.weapon_idx, hit["headshot"])
			plugin_manager.dispatch_on_player_death(victim_id, peer_id)
			_send_death_report(victim_id)
			var kill_flags := 0
			if hit.get("wallbang", false):
				kill_flags |= NetProtocol.KILL_FLAG_WALLBANG
			if _is_in_smoke(sp.body.global_position) or _is_in_smoke(victim_sp.body.global_position):
				kill_flags |= NetProtocol.KILL_FLAG_SMOKE
			if victim_sp.body.get("_flash_blind") != null and victim_sp.body._flash_blind > 0.0:
				kill_flags |= NetProtocol.KILL_FLAG_FLASH
			var kill_packet := NetProtocol.pack_kill_event(
				peer_id, victim_id, sp.weapon_idx, hit["headshot"], kill_flags)
			for pid in players:
				multiplayer.send_bytes(kill_packet, pid,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE,
					NetConstants.CHANNEL_EVENTS)
			print("[Server] KILL: Player %d → Player %d (%s, dmg=%.1f%s) [K:%d D:%d]" % [
				peer_id, victim_id, hit["hitgroup"], final_damage,
				_kill_flags_str(kill_flags),
				sp.kills, victim_sp.deaths])


func _process_respawns() -> void:
	for peer_id in players:
		var sp = players[peer_id]
		if not sp.is_dead:
			continue
		if sp.respawn_tick <= 0 or server_tick < sp.respawn_tick:
			continue

		if not plugin_manager.dispatch_can_player_respawn(peer_id):
			continue

		var spawn_pos: Vector3 = plugin_manager.dispatch_get_spawn_position(peer_id)
		if spawn_pos == Vector3.ZERO:
			spawn_pos = spawn_points[randi() % spawn_points.size()]
		sp.respawn(spawn_pos)
		plugin_manager.dispatch_on_player_spawn(peer_id, spawn_pos)

		var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
		for pid in players:
			multiplayer.send_bytes(spawn_packet, pid,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetConstants.CHANNEL_EVENTS)
		print("[Server] Player %d respawned at %s" % [peer_id, spawn_pos])


func _process_use_commands(delta: float) -> void:
	for peer_id in players:
		var sp = players[peer_id]
		if sp.is_dead:
			if _use_state.get(peer_id, false):
				plugin_manager.dispatch_on_player_use_release(peer_id)
				_use_state[peer_id] = false
			continue

		var cmd: NetInput = sp.last_input
		var wants_use: bool = cmd.has_button(NetInput.BIT_USE)
		var was_using: bool = _use_state.get(peer_id, false)

		if wants_use:
			plugin_manager.dispatch_on_player_use(peer_id, sp.body.global_position, delta)
		elif was_using:
			plugin_manager.dispatch_on_player_use_release(peer_id)

		_use_state[peer_id] = wants_use


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
	elif admin_type == NetProtocol.ADMIN_BUY:
		if packet.size() < 4:
			return
		var item_index: int = packet[3]
		_handle_buy(peer_id, item_index)
	elif admin_type == NetProtocol.ADMIN_REQUEST:
		if packet.size() < 4:
			return
		var item_index: int = packet[3]
		_handle_weapon_request(peer_id, item_index)
	elif admin_type == NetProtocol.ADMIN_CHAT:
		if packet.size() < 6:
			return
		var team_only: bool = packet[3] != 0
		var msg_len: int = packet[4] | (packet[5] << 8)
		if packet.size() < 6 + msg_len or msg_len == 0 or msg_len > 256:
			return
		var message := packet.slice(6, 6 + msg_len).get_string_from_utf8()
		_handle_chat(peer_id, message, team_only)
	elif admin_type == NetProtocol.ADMIN_TEAM_SELECT:
		if packet.size() < 4:
			return
		var requested_team: int = packet[3]
		_handle_team_select(peer_id, requested_team)
	elif admin_type == NetProtocol.ADMIN_GRENADE:
		if packet.size() >= 32:
			_handle_grenade_throw(peer_id, packet)


func _handle_team_select(peer_id: int, requested_team: int) -> void:
	var mode: GamePlugin = plugin_manager.get_mode_plugin()
	if mode == null or not mode.has_method("change_team"):
		return
	if not players.has(peer_id):
		return
	var success: bool = mode.change_team(peer_id, requested_team)
	if success:
		_broadcast_match_state()
	else:
		_send_server_msg(peer_id, "Team change denied: teams would be unbalanced")


func _handle_buy(peer_id: int, item_index: int) -> void:
	if not players.has(peer_id):
		return
	var sp = players[peer_id]
	if sp.is_dead:
		_send_buy_result(peer_id, false, item_index)
		return

	var item := BuyCatalog.get_item(item_index)
	if item.is_empty():
		_send_buy_result(peer_id, false, item_index)
		return

	var team := plugin_manager.dispatch_get_player_team(peer_id)
	var attack_team := plugin_manager.dispatch_get_attack_team()
	var money := plugin_manager.dispatch_get_player_money(peer_id)
	var check := BuyCatalog.can_buy(item_index, money, team, attack_team,
		sp.weapon_idx, sp.armor)
	if not check["ok"]:
		_send_buy_result(peer_id, false, item_index)
		return

	if not plugin_manager.dispatch_can_purchase(
			peer_id, item["id"], item["price"], sp.body.global_position):
		_send_buy_result(peer_id, false, item_index)
		return

	if not plugin_manager.dispatch_deduct_money(peer_id, item["price"]):
		_send_buy_result(peer_id, false, item_index)
		return

	var slot: int = item["slot"]
	if slot == BuyCatalog.Slot.ARMOR:
		sp.armor = item.get("armor_value", 0)
	else:
		sp.set_weapon(item["weapon_idx"])

	var new_money := plugin_manager.dispatch_get_player_money(peer_id)
	plugin_manager.dispatch_on_purchase(peer_id, item["id"], item["price"])
	_send_buy_result(peer_id, true, item_index)
	print("[Server] Player %d bought %s ($%d → $%d)" % [
		peer_id, item["id"], item["price"], new_money])


func _handle_weapon_request(peer_id: int, item_index: int) -> void:
	if not players.has(peer_id):
		return
	var item := BuyCatalog.get_item(item_index)
	if item.is_empty():
		return
	var team := plugin_manager.dispatch_get_player_team(peer_id)
	var packet := NetProtocol.pack_buy_request_event(peer_id, item_index)
	for pid in players:
		if pid == peer_id:
			continue
		if plugin_manager.dispatch_get_player_team(pid) == team:
			multiplayer.send_bytes(packet, pid,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetConstants.CHANNEL_EVENTS)
	print("[Server] Player %d requested %s from teammates" % [peer_id, item["id"]])


func _handle_chat(peer_id: int, message: String, team_only: bool) -> void:
	if not players.has(peer_id):
		return
	if message.begins_with("/"):
		_handle_chat_command(peer_id, message)
		return
	var filtered := plugin_manager.dispatch_on_chat_message(peer_id, message, team_only)
	if filtered.is_empty():
		return

	var chat_plugin: PluginChat = plugin_manager.get_plugin(&"chat") as PluginChat
	var effective_team := team_only
	if chat_plugin and chat_plugin.should_force_all_chat(peer_id):
		effective_team = false

	var recipients: Array[int]
	if chat_plugin:
		recipients = chat_plugin.get_eligible_peers(peer_id, effective_team, players)
	else:
		for pid in players:
			recipients.append(pid)

	var packet := NetProtocol.pack_chat_event(peer_id, filtered, effective_team)
	for pid in recipients:
		multiplayer.send_bytes(packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)
	var scope := "(TEAM)" if effective_team else "(ALL)"
	print("[Server] CHAT %s Player %d: %s" % [scope, peer_id, filtered])


func _send_buy_result(peer_id: int, success: bool, item_index: int) -> void:
	var money := plugin_manager.dispatch_get_player_money(peer_id)
	var packet := NetProtocol.pack_buy_result_event(success, item_index, money)
	multiplayer.send_bytes(packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)


func _spawn_new_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	pending_peers.erase(peer_id)

	if not plugin_manager.dispatch_on_player_pre_spawn(peer_id):
		return

	var token := next_token
	next_token += 1

	var spawn_pos: Vector3 = plugin_manager.dispatch_get_spawn_position(peer_id)
	if spawn_pos == Vector3.ZERO:
		spawn_pos = spawn_points[next_spawn % spawn_points.size()]
		next_spawn += 1

	var sp = ServerPlayer.new()
	sp.create(peer_id, spawn_pos, world_node)
	players[peer_id] = sp
	peer_tokens[peer_id] = token
	plugin_manager.dispatch_on_player_connect(peer_id)
	plugin_manager.dispatch_on_player_spawn(peer_id, spawn_pos)

	var session_packet := NetProtocol.pack_session_event(token)
	multiplayer.send_bytes(session_packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)

	var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
	for pid in players:
		multiplayer.send_bytes(spawn_packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

	_send_match_state_to(peer_id)
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
	plugin_manager.dispatch_on_player_connect(peer_id)

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
	if plugin_manager.dispatch_on_console_command(cmd, args):
		return

	match cmd:
		"status":
			_cmd_status()
		"kick":
			_cmd_kick(args)
		"say":
			_cmd_say(args)
		"quit":
			_cmd_quit()
		"plugins":
			_cmd_plugins()
		"settings":
			_cmd_settings()
		_:
			print("[Console] Unknown command: %s" % cmd)


func _cmd_status() -> void:
	print("[Console] === Server Status (tick %d) ===" % server_tick)
	print("[Console] Mode: %s" % plugin_manager.get_client_mode())
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
	_broadcast_server_msg(args)


func _cmd_quit() -> void:
	print("[Console] ADMIN: Server shutting down")
	_broadcast_server_msg("Server shutting down")
	if console:
		console.stop()
	get_tree().quit()


func _cmd_plugins() -> void:
	print("[Console] === Loaded Plugins ===")
	var mode: GamePlugin = plugin_manager.get_mode_plugin()
	for p in plugin_manager.plugins:
		var tag := ""
		if p == mode:
			tag = " [MODE]"
		print("[Console]   %s v%s%s — %s" % [
			p.get_plugin_name(), p.get_plugin_version(), tag, p.get_description()])
	print("[Console] Total: %d plugin(s)" % plugin_manager.plugins.size())


func _cmd_settings() -> void:
	print("[Console] === Match Settings ===")
	var settings: Array = plugin_manager.match_config.list_settings()
	if settings.is_empty():
		print("[Console] No settings registered")
		return
	for s in settings:
		print("[Console]   %s = %s  (default: %s, from: %s)" % [
			s["name"], str(s["value"]), str(s["default"]), s["plugin"]])


func _handle_grenade_throw(peer_id: int, packet: PackedByteArray) -> void:
	if not players.has(peer_id):
		return
	var sp = players[peer_id]
	if sp.is_dead:
		return

	var grenade_type: int = packet[3]
	if grenade_type > 2:
		return
	if not sp.consume_grenade(grenade_type):
		return

	var pos := Vector3(packet.decode_float(4), packet.decode_float(8), packet.decode_float(12))
	var vel := Vector3(packet.decode_float(16), packet.decode_float(20), packet.decode_float(24))
	var fuse: float = packet.decode_float(28)
	fuse = clampf(fuse, 0.0, WC.GRENADE_FUSE)

	var gid := next_grenade_id
	next_grenade_id += 1

	var body := RigidBody3D.new()
	body.collision_layer = 4
	body.collision_mask = 1

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = WC.GRENADE_BOUNCE
	phys_mat.friction = WC.GRENADE_FRICTION
	body.physics_material_override = phys_mat

	var project_grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if project_grav > 0.0:
		body.gravity_scale = (MC.GRAVITY * 0.4) / project_grav

	body.linear_damp = 0.1
	body.angular_damp = 2.0
	body.continuous_cd = true

	var shape := SphereShape3D.new()
	shape.radius = 0.04
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)

	world_node.add_child(body)
	body.global_position = pos
	body.linear_velocity = vel

	active_grenades.append({
		"body": body,
		"id": gid,
		"type": grenade_type,
		"thrower": peer_id,
		"fuse": fuse,
	})

	var spawn_packet := NetProtocol.pack_grenade_spawn_event(
		peer_id, gid, grenade_type, pos, vel, fuse)
	for pid in players:
		multiplayer.send_bytes(spawn_packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

	print("[Server] Player %d threw grenade type=%d id=%d fuse=%.2f" % [
		peer_id, grenade_type, gid, fuse])


func _process_grenades(delta: float) -> void:
	var to_detonate: Array = []
	for g in active_grenades:
		g["fuse"] -= delta
		if g["fuse"] <= 0.0:
			to_detonate.append(g)
	for g in to_detonate:
		_detonate_grenade(g)
		active_grenades.erase(g)
		if is_instance_valid(g["body"]):
			g["body"].queue_free()


func _detonate_grenade(g: Dictionary) -> void:
	var pos: Vector3 = g["body"].global_position if is_instance_valid(g["body"]) else Vector3.ZERO
	var grenade_type: int = g["type"]
	var thrower_id: int = g["thrower"]

	var det_packet := NetProtocol.pack_grenade_detonate_event(g["id"], grenade_type, pos)
	for pid in players:
		multiplayer.send_bytes(det_packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)

	match grenade_type:
		0: _detonate_he_server(thrower_id, pos)
		1: _detonate_flash_server(thrower_id, pos)
		2: _detonate_smoke_server(pos)


func _detonate_he_server(thrower_id: int, pos: Vector3) -> void:
	var blast_radius_m := WC.HE_BLAST_RADIUS_GSRC * MC.METERS_PER_UNIT
	var space := world_node.get_world_3d().direct_space_state
	var damaged: Dictionary = {}

	for peer_id in players:
		var sp = players[peer_id]
		if sp.is_dead:
			continue
		if damaged.has(peer_id):
			continue

		var target_pos: Vector3 = sp.body.global_position
		var dist_m := pos.distance_to(target_pos)
		var dist_gsrc := dist_m * MC.UNITS_PER_METER
		if dist_gsrc >= WC.HE_BLAST_RADIUS_GSRC:
			continue

		var check_from := pos + Vector3(0, 0.1, 0)
		var check_to := target_pos + Vector3(0, 0.5, 0)
		var los_params := PhysicsRayQueryParameters3D.create(check_from, check_to)
		los_params.collision_mask = 1
		los_params.exclude = [sp.body.get_rid()]
		var los_result := space.intersect_ray(los_params)
		if los_result:
			continue

		var base_damage := WC.HE_DAMAGE * (1.0 - dist_gsrc / WC.HE_BLAST_RADIUS_GSRC)
		var final_damage: float = plugin_manager.dispatch_on_player_damage(
			thrower_id, peer_id, base_damage, -1, "chest")
		if final_damage <= 0.0:
			continue

		sp.take_damage(final_damage)
		damaged[peer_id] = true

		damage_log.append({
			"attacker": thrower_id,
			"victim": peer_id,
			"damage": int(ceilf(final_damage)),
			"weapon": -1,
			"headshot": false,
		})

		if players.has(thrower_id):
			var hit_packet := NetProtocol.pack_hit_event(
				peer_id, int(final_damage), false)
			multiplayer.send_bytes(hit_packet, thrower_id,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetConstants.CHANNEL_EVENTS)

		if sp.is_dead:
			sp.die(server_tick)
			if players.has(thrower_id):
				players[thrower_id].kills += 1
			plugin_manager.last_death_position = sp.body.global_position
			plugin_manager.dispatch_on_player_kill(thrower_id, peer_id, -1, false)
			plugin_manager.dispatch_on_player_death(peer_id, thrower_id)
			_send_death_report(peer_id)
			var kill_flags := 0
			if _is_in_smoke(pos) or _is_in_smoke(sp.body.global_position):
				kill_flags |= NetProtocol.KILL_FLAG_SMOKE
			var kill_packet := NetProtocol.pack_kill_event(
				thrower_id, peer_id, -1, false, kill_flags)
			for pid in players:
				multiplayer.send_bytes(kill_packet, pid,
					MultiplayerPeer.TRANSFER_MODE_RELIABLE,
					NetConstants.CHANNEL_EVENTS)
			print("[Server] GRENADE KILL: Player %d → Player %d (HE, dmg=%.1f)" % [
				thrower_id, peer_id, final_damage])


func _detonate_flash_server(thrower_id: int, pos: Vector3) -> void:
	var space := world_node.get_world_3d().direct_space_state

	for peer_id in players:
		var sp = players[peer_id]
		if sp.is_dead:
			continue

		var eye_pos: Vector3 = sp.body.get_node("Head").global_position

		var los_params := PhysicsRayQueryParameters3D.create(
			pos + Vector3(0, 0.1, 0), eye_pos)
		los_params.collision_mask = 1
		los_params.exclude = [sp.body.get_rid()]
		var los_result := space.intersect_ray(los_params)
		if los_result:
			continue

		var cam_yaw := deg_to_rad(fposmod(rad_to_deg(sp.body.rotation.y), 360.0))
		var cam_pitch: float = sp.body.get_node("Head").rotation.x
		var cam_forward := Vector3(
			-sin(cam_yaw) * cos(cam_pitch),
			sin(cam_pitch),
			-cos(cam_yaw) * cos(cam_pitch)).normalized()
		var dir_to_flash := pos - eye_pos
		cam_forward.y = 0.0
		dir_to_flash.y = 0.0
		cam_forward = cam_forward.normalized()
		dir_to_flash = dir_to_flash.normalized()
		var dot := cam_forward.dot(dir_to_flash)
		var angle_deg := rad_to_deg(acos(clampf(dot, -1.0, 1.0)))

		var blind := _lerp_flash_angle(angle_deg, WC.FLASH_ANGLES, WC.FLASH_BLIND)
		var fade := _lerp_flash_angle(angle_deg, WC.FLASH_ANGLES, WC.FLASH_FADE)

		if blind <= 0.0 and fade <= 0.0:
			fade = WC.FLASH_TINT_TIME
		if blind <= 0.0 and fade <= 0.0:
			continue

		sp.body._flash_blind = blind

		var flash_packet := NetProtocol.pack_flash_event(blind, fade)
		multiplayer.send_bytes(flash_packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)


func _detonate_smoke_server(pos: Vector3) -> void:
	var cloud := Node3D.new()
	cloud.set_script(preload("res://shared/scripts/smoke_cloud.gd"))
	world_node.add_child(cloud)
	cloud.global_position = pos


func _lerp_flash_angle(angle: float, angles: Array, values: Array) -> float:
	if angle <= float(angles[0]):
		return float(values[0])
	for i in range(1, angles.size()):
		if angle <= float(angles[i]):
			var t: float = (angle - float(angles[i - 1])) / (float(angles[i]) - float(angles[i - 1]))
			return lerpf(float(values[i - 1]), float(values[i]), t)
	return float(values[values.size() - 1])


func _is_in_smoke(pos: Vector3) -> bool:
	var smoke_radius: float = WC.SMOKE_RADIUS_GSRC * MC.METERS_PER_UNIT
	for cloud in get_tree().get_nodes_in_group("smoke_cloud"):
		if pos.distance_to(cloud.global_position) <= smoke_radius:
			return true
	return false


func _kill_flags_str(flags: int) -> String:
	var parts: Array[String] = []
	if flags & NetProtocol.KILL_FLAG_WALLBANG:
		parts.append("WB")
	if flags & NetProtocol.KILL_FLAG_SMOKE:
		parts.append("SMOKE")
	if flags & NetProtocol.KILL_FLAG_FLASH:
		parts.append("FLASH")
	if parts.is_empty():
		return ""
	return " [%s]" % ", ".join(parts)


func _on_plugin_event(event_name: StringName, _data: Dictionary) -> void:
	if event_name == &"round_reset":
		_reset_round_players()
		_broadcast_match_state()
	elif event_name == &"roster_changed" or event_name == &"match_state_changed":
		_broadcast_match_state()


func _broadcast_match_state() -> void:
	var mode := plugin_manager.get_client_mode()
	if mode == &"":
		return
	var state := plugin_manager.get_client_state()
	for peer_id in players:
		state["my_team"] = plugin_manager.dispatch_get_player_team(peer_id)
		state["money"] = plugin_manager.dispatch_get_player_money(peer_id)
		var packet := NetProtocol.pack_match_state_event(mode, state)
		multiplayer.send_bytes(packet, peer_id,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)


func _send_match_state_to(peer_id: int) -> void:
	var mode := plugin_manager.get_client_mode()
	if mode == &"":
		return
	var state := plugin_manager.get_client_state()
	state["my_team"] = plugin_manager.dispatch_get_player_team(peer_id)
	state["money"] = plugin_manager.dispatch_get_player_money(peer_id)
	var packet := NetProtocol.pack_match_state_event(mode, state)
	multiplayer.send_bytes(packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)


func _send_death_report(victim_id: int) -> void:
	var given: Dictionary = {}
	var taken: Dictionary = {}
	for entry in damage_log:
		if entry["attacker"] == victim_id:
			var vid: int = entry["victim"]
			if not given.has(vid):
				given[vid] = {"id": vid, "dmg": 0, "hits": 0, "hs": 0}
			given[vid]["dmg"] += entry["damage"]
			given[vid]["hits"] += 1
			if entry["headshot"]:
				given[vid]["hs"] += 1
		if entry["victim"] == victim_id:
			var aid: int = entry["attacker"]
			if not taken.has(aid):
				taken[aid] = {"id": aid, "dmg": 0, "hits": 0, "hs": 0}
			taken[aid]["dmg"] += entry["damage"]
			taken[aid]["hits"] += 1
			if entry["headshot"]:
				taken[aid]["hs"] += 1
	var report := {"given": given.values(), "taken": taken.values()}
	var packet := NetProtocol.pack_death_report_event(victim_id, report)
	multiplayer.send_bytes(packet, victim_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)


func _reset_round_players() -> void:
	damage_log.clear()
	for g in active_grenades:
		if is_instance_valid(g["body"]):
			g["body"].queue_free()
	active_grenades.clear()
	for peer_id in players:
		var sp = players[peer_id]
		var spawn_pos: Vector3 = plugin_manager.dispatch_get_spawn_position(peer_id)
		if spawn_pos == Vector3.ZERO:
			spawn_pos = spawn_points[randi() % spawn_points.size()]

		if sp.is_dead:
			sp.respawn(spawn_pos)
		else:
			sp.teleport_to_spawn(spawn_pos)

		var spawn_packet := NetProtocol.pack_spawn_event(peer_id, spawn_pos)
		for pid in players:
			multiplayer.send_bytes(spawn_packet, pid,
				MultiplayerPeer.TRANSFER_MODE_RELIABLE,
				NetConstants.CHANNEL_EVENTS)
	print("[Server] Round reset: %d players respawned" % players.size())


func _handle_chat_command(peer_id: int, raw: String) -> void:
	var parts := raw.strip_edges().split(" ", false, 1)
	var cmd := parts[0].to_lower()
	var args := parts[1].strip_edges() if parts.size() > 1 else ""

	match cmd:
		"/mode":
			_cmd_chat_mode(peer_id, args)
		"/map":
			_cmd_chat_map(peer_id, args)
		"/restart":
			_cmd_chat_restart(peer_id)
		"/help":
			_cmd_chat_help(peer_id)
		_:
			_send_server_msg(peer_id, "Unknown command: %s (type /help)" % cmd)


func _cmd_chat_mode(peer_id: int, args: String) -> void:
	var mode_name := args.to_lower()
	if mode_name.is_empty():
		var current := plugin_manager.get_client_mode()
		_send_server_msg(peer_id, "Current mode: %s. Usage: /mode <%s>" % [current, "|".join(VALID_MODES)])
		return
	if mode_name not in VALID_MODES:
		_send_server_msg(peer_id, "Unknown mode: %s. Available: %s" % [mode_name, ", ".join(VALID_MODES)])
		return
	if mode_name == String(plugin_manager.get_client_mode()):
		_send_server_msg(peer_id, "Already in %s mode" % mode_name)
		return
	_change_mode(mode_name)
	_broadcast_server_msg("Mode changed to %s by Player %d" % [mode_name, peer_id])


func _cmd_chat_map(peer_id: int, args: String) -> void:
	var map_name := args.to_lower()
	if map_name.is_empty():
		_send_server_msg(peer_id, "Current map: MAP_DM_AIM. Usage: /map <name>")
		return
	if map_name == "map_dm_aim":
		_send_server_msg(peer_id, "Already on MAP_DM_AIM")
	else:
		_send_server_msg(peer_id, "Unknown map: %s. Available: MAP_DM_AIM" % map_name)


func _cmd_chat_restart(peer_id: int) -> void:
	_broadcast_server_msg("Round restarted by Player %d" % peer_id)
	_reset_round_players()
	_broadcast_match_state()


func _cmd_chat_help(peer_id: int) -> void:
	_send_server_msg(peer_id, "Commands: /mode <%s>, /map <name>, /restart, /help" % "|".join(VALID_MODES))


func _change_mode(mode_name: String) -> void:
	var old_mode := plugin_manager.get_mode_plugin()
	if old_mode:
		plugin_manager.unload_plugin(old_mode)

	var new_mode := _create_mode_plugin(mode_name)
	plugin_manager.load_plugin(new_mode)

	if world_node.get("angels_spawns") and world_node.get("demons_spawns"):
		plugin_manager.set_map_spawns(world_node.angels_spawns, world_node.demons_spawns)
	if world_node.get("portal_sites"):
		plugin_manager.set_map_portal_sites(world_node.portal_sites)

	_reset_round_players()
	_broadcast_match_state()
	print("[Server] Mode changed to: %s" % mode_name)


const VALID_MODES := ["deathmatch", "competitive", "tdm", "casual"]

func _create_mode_plugin(mode_name: String) -> GamePlugin:
	match mode_name:
		"deathmatch":
			return PluginDeathmatch.new()
		"competitive":
			return PluginCompetitive.new()
		"tdm":
			return PluginTeamDeathmatch.new()
		"casual":
			return PluginCasual.new()
		_:
			push_warning("Unknown mode '%s', falling back to deathmatch" % mode_name)
			return PluginDeathmatch.new()


func _send_server_msg(peer_id: int, message: String) -> void:
	var packet := NetProtocol.pack_server_msg_event(message)
	multiplayer.send_bytes(packet, peer_id,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_EVENTS)


func _broadcast_server_msg(message: String) -> void:
	var packet := NetProtocol.pack_server_msg_event(message)
	for pid in players:
		multiplayer.send_bytes(packet, pid,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_EVENTS)
