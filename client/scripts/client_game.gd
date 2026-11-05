extends Node

const ClientInterpolation = preload("res://client/scripts/client_interpolation.gd")

var client_tick: int = 0
var server_tick: int = 0
var tick_synced: bool = false

var input_buffer: Array = []
var recent_inputs: Array = []

var local_player: CharacterBody3D
var snapshot_buffer: Array = []
var last_received_snapshot_tick: int = 0

var prediction_buffer: Array = []
var correction_offset := Vector3.ZERO
var correction_origin := Vector3.ZERO
var correction_timer: float = 0.0
var correction_count: int = 0
var _pending_reconcile = null

var snapshots_received: int = 0
var my_peer_id: int = 0
var interpolation: Node = null
var player_stats: Dictionary = {}
var _team_map: Dictionary = {}
var buy_menu: ClientBuyMenu
var mode_loader: ClientModeLoader
var hud: ClientHud
var spectator: ClientSpectator
var chat: ClientChat
var team_select: ClientTeamSelect
var death_report: ClientDeathReport
var _team_select_shown: bool = false

var session_token: int = 0
var server_address: String = "127.0.0.1"
var server_port: int = NetworkManager.DEFAULT_PORT
var reconnecting: bool = false
var reconnect_timer: float = 0.0
var reconnect_elapsed: float = 0.0
var reconnect_label: Label
const RECONNECT_INTERVAL := 2.0
const RECONNECT_MAX_TIME := 30.0


func _ready() -> void:
	add_to_group("client_game")
	Engine.physics_ticks_per_second = NetConstants.TICK_RATE
	process_physics_priority = -1

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--join="):
			server_address = arg.get_slice("=", 1)
		elif arg.begins_with("--port="):
			server_port = arg.get_slice("=", 1).to_int()

	_setup_reconnect_overlay()

	multiplayer.peer_packet.connect(_on_peer_packet)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var player := get_node_or_null("Player")
	if player:
		set_local_player(player)

	var interp_node := Node3D.new()
	interp_node.name = "Interpolation"
	interp_node.set_script(ClientInterpolation)
	add_child(interp_node)
	interpolation = interp_node

	mode_loader = ClientModeLoader.new()

	buy_menu = ClientBuyMenu.new()
	buy_menu.name = "BuyMenu"
	add_child(buy_menu)
	buy_menu.buy_requested.connect(_on_buy_requested)
	buy_menu.weapon_requested.connect(_on_weapon_requested)

	hud = ClientHud.new()
	hud.name = "HUD"
	add_child(hud)

	spectator = ClientSpectator.new()
	spectator.name = "Spectator"
	spectator.interpolation = interpolation
	add_child(spectator)

	chat = ClientChat.new()
	chat.name = "Chat"
	add_child(chat)

	team_select = ClientTeamSelect.new()
	team_select.name = "TeamSelect"
	add_child(team_select)
	team_select.team_selected.connect(_on_team_selected)

	death_report = ClientDeathReport.new()
	death_report.name = "DeathReport"
	add_child(death_report)

	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		my_peer_id = multiplayer.get_unique_id() & 0xFFFF
		print("[Client] Already connected (peer ID: %d)" % my_peer_id)
	else:
		var err := NetworkManager.join_server(server_address, server_port)
		if err != OK:
			push_error("Failed to connect to %s:%d" % [server_address, server_port])
			get_tree().quit(1)


func _on_connected() -> void:
	my_peer_id = multiplayer.get_unique_id() & 0xFFFF
	print("[Client] Connected to server (peer ID: %d, net ID: %d)" % [my_peer_id, multiplayer.get_unique_id()])

	if reconnecting:
		reconnecting = false
		reconnect_label.visible = false
		reconnect_elapsed = 0.0
		tick_synced = false
		snapshot_buffer.clear()
		prediction_buffer.clear()
		input_buffer.clear()
		recent_inputs.clear()
		print("[Client] Reconnected successfully")

	if session_token > 0:
		var packet := NetProtocol.pack_rejoin_request(session_token)
		multiplayer.send_bytes(packet, 1,
			MultiplayerPeer.TRANSFER_MODE_RELIABLE,
			NetConstants.CHANNEL_ADMIN)


func _on_connection_failed() -> void:
	if reconnecting:
		print("[Client] Reconnect attempt failed, will retry...")
		return
	print("[Client] Connection failed")
	get_tree().quit(1)


func _on_server_disconnected() -> void:
	print("[Client] Server disconnected")
	if session_token > 0 and not reconnecting:
		_start_reconnect()


func _physics_process(_delta: float) -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var _spectating: bool = spectator != null and spectator.is_spectating()

	var visual_yaw := 0.0
	var visual_pitch := 0.0
	if local_player and not _spectating:
		visual_yaw = local_player.rotation.y
		visual_pitch = local_player.get_node("Head").rotation.x

	if _pending_reconcile != null and not _spectating:
		_try_reconcile(_pending_reconcile)
		_pending_reconcile = null

	if local_player and not _spectating:
		local_player.rotation.y = visual_yaw
		local_player.get_node("Head").rotation.x = visual_pitch

	if local_player and client_tick > 0 and not _spectating:
		_store_prediction(client_tick)

	client_tick += 1

	if not _spectating:
		var cmd := _sample_input()
		_store_input(cmd)

		if local_player:
			local_player.apply_network_input(cmd.yaw, cmd.pitch,
				cmd.has_button(NetInput.BIT_FORWARD), cmd.has_button(NetInput.BIT_BACK),
				cmd.has_button(NetInput.BIT_LEFT), cmd.has_button(NetInput.BIT_RIGHT),
				cmd.has_button(NetInput.BIT_JUMP), cmd.has_button(NetInput.BIT_DUCK),
				cmd.has_button(NetInput.BIT_WALK))
			local_player.test_driven = false
			local_player.simulate_tick(NetConstants.TICK_INTERVAL)
			local_player.test_driven = true
			local_player.rotation.y = visual_yaw
			local_player.get_node("Head").rotation.x = visual_pitch

	if client_tick % 2 == 0:
		_send_input()


func _process(delta: float) -> void:
	if correction_timer > 0.0:
		correction_timer -= delta
		if correction_timer <= 0.0:
			correction_offset = Vector3.ZERO
			correction_origin = Vector3.ZERO
			correction_timer = 0.0
		else:
			var t := correction_timer / NetConstants.RECONCILE_SMOOTH_TIME
			correction_offset = correction_origin * t

	if local_player and not (spectator and spectator.is_spectating()):
		var cam := local_player.get_node_or_null("Head/Camera3D")
		if cam:
			cam.position = Vector3.ZERO
			if correction_offset.length_squared() > 0.00001:
				var head_basis_inv: Basis = cam.get_parent().global_transform.basis.inverse()
				cam.position = head_basis_inv * correction_offset

	if reconnecting:
		reconnect_elapsed += delta
		if reconnect_elapsed >= RECONNECT_MAX_TIME:
			reconnecting = false
			reconnect_label.text = "Connection lost"
			print("[Client] Reconnect timed out after %.0fs" % RECONNECT_MAX_TIME)
			return
		reconnect_timer -= delta
		if reconnect_timer <= 0.0:
			reconnect_timer = RECONNECT_INTERVAL
			_attempt_reconnect()
		reconnect_label.text = "Reconnecting... (%.0fs)" % (RECONNECT_MAX_TIME - reconnect_elapsed)


func _sample_input() -> NetInput:
	var cmd := NetInput.new()
	cmd.tick = client_tick

	if local_player:
		cmd.yaw = fposmod(rad_to_deg(local_player.rotation.y), 360.0)
		cmd.pitch = rad_to_deg(local_player.get_node("Head").rotation.x)
		var yaw_q := int(fmod(cmd.yaw, 360.0) * NetConstants.YAW_SCALE) & 0xFFFF
		cmd.yaw = float(yaw_q) / NetConstants.YAW_SCALE
		var pitch_q := clampi(int(cmd.pitch * NetConstants.PITCH_SCALE), -32768, 32767)
		cmd.pitch = float(pitch_q) / NetConstants.PITCH_SCALE

	cmd.set_button(NetInput.BIT_FORWARD, Input.is_action_pressed("move_forward"))
	cmd.set_button(NetInput.BIT_BACK, Input.is_action_pressed("move_backward"))
	cmd.set_button(NetInput.BIT_LEFT, Input.is_action_pressed("move_left"))
	cmd.set_button(NetInput.BIT_RIGHT, Input.is_action_pressed("move_right"))
	cmd.set_button(NetInput.BIT_JUMP, Input.is_action_pressed("jump") or (local_player and local_player.scroll_jump_queued))
	cmd.set_button(NetInput.BIT_DUCK, Input.is_action_pressed("duck"))
	cmd.set_button(NetInput.BIT_WALK, Input.is_action_pressed("walk"))
	cmd.set_button(NetInput.BIT_FIRE, Input.is_action_pressed("fire"))
	cmd.set_button(NetInput.BIT_FIRE2, Input.is_action_pressed("fire_secondary"))
	cmd.set_button(NetInput.BIT_RELOAD, Input.is_action_pressed("reload"))
	cmd.set_button(NetInput.BIT_WEAPON1, Input.is_action_pressed("weapon_1"))
	cmd.set_button(NetInput.BIT_WEAPON2, Input.is_action_pressed("weapon_2"))
	cmd.set_button(NetInput.BIT_WEAPON3, Input.is_action_pressed("weapon_3"))
	cmd.set_button(NetInput.BIT_WEAPON4, Input.is_action_pressed("weapon_4"))
	cmd.set_button(NetInput.BIT_WEAPON5, Input.is_action_pressed("weapon_5"))

	return cmd


func _store_input(cmd: NetInput) -> void:
	input_buffer.append(cmd)
	if input_buffer.size() > NetConstants.INPUT_BUFFER_SIZE:
		input_buffer.pop_front()

	recent_inputs.append(cmd)
	if recent_inputs.size() > NetConstants.INPUT_REDUNDANCY:
		recent_inputs.pop_front()


func _store_prediction(tick: int) -> void:
	var pos := local_player.global_position
	var prec := NetConstants.POS_PRECISION
	var qpos := Vector3(
		float(int(pos.x / prec)) * prec,
		float(int(pos.y / prec)) * prec,
		float(int(pos.z / prec)) * prec,
	)
	prediction_buffer.append({
		"tick": tick,
		"position": qpos,
		"velocity": local_player.velocity,
		"on_ground": local_player.on_ground,
		"is_ducked": local_player.is_ducked,
	})
	if prediction_buffer.size() > NetConstants.INPUT_BUFFER_SIZE:
		prediction_buffer.pop_front()


func _find_prediction(tick: int) -> Dictionary:
	for i in range(prediction_buffer.size() - 1, -1, -1):
		if prediction_buffer[i]["tick"] == tick:
			return prediction_buffer[i]
	return {}


func _find_input(tick: int) -> NetInput:
	for i in range(input_buffer.size() - 1, -1, -1):
		if input_buffer[i].tick == tick:
			return input_buffer[i]
	return null


func _send_input() -> void:
	if recent_inputs.is_empty():
		return
	var packet := NetProtocol.pack_input_packet(recent_inputs, last_received_snapshot_tick)
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
	elif msg_type == NetProtocol.MSG_EVENT:
		_handle_event(packet)


func _handle_snapshot(packet: PackedByteArray) -> void:
	var bases: Dictionary = {}
	if snapshot_buffer.size() > 0:
		var base_snap: Dictionary = snapshot_buffer[snapshot_buffer.size() - 1]
		if packet.size() >= NetProtocol.HEADER_SIZE + 8 and packet[7] == 1:
			var base_tick: int = packet[8] | (packet[9] << 8) | (packet[10] << 16) | (packet[11] << 24)
			for i in range(snapshot_buffer.size() - 1, -1, -1):
				if snapshot_buffer[i]["tick"] == base_tick:
					base_snap = snapshot_buffer[i]
					break
		for s in base_snap["states"]:
			bases[s.peer_id] = s

	var result := NetProtocol.unpack_snapshot(packet, bases)
	if result["states"].is_empty():
		return

	snapshot_buffer.append(result)
	if snapshot_buffer.size() > NetConstants.SNAPSHOT_BUFFER_SIZE:
		snapshot_buffer.pop_front()

	server_tick = result["tick"]
	last_received_snapshot_tick = server_tick
	snapshots_received += 1

	if not tick_synced:
		var lead := _compute_tick_lead()
		client_tick = server_tick + lead
		tick_synced = true
		print("[Client] Tick synced: server=%d client=%d (lead=%d)" % [server_tick, client_tick, lead])

	if my_peer_id > 0 and hud:
		for s in result["states"]:
			if s.peer_id == my_peer_id:
				hud.update_from_snapshot(s.hp, s.armor, s.weapon_idx, s.ammo_mag)
				break

	# Reconciliation: compare server state to our prediction
	if local_player and my_peer_id > 0:
		_pending_reconcile = result

	if interpolation:
		interpolation.on_snapshot(result, my_peer_id)

	if snapshots_received % 128 == 0:
		print("[Client] Snapshot %d: tick=%d corrections=%d" % [
			snapshots_received, server_tick, correction_count])


func _try_reconcile(snapshot_result: Dictionary) -> void:
	var server_state: NetSnapshot = null
	for s in snapshot_result["states"]:
		if s.peer_id == my_peer_id:
			server_state = s
			break
	if server_state == null:
		return

	var snap_tick: int = snapshot_result["tick"]
	var predicted := _find_prediction(snap_tick)
	if predicted.is_empty():
		return

	var error: float = predicted["position"].distance_to(server_state.position)
	if error <= NetConstants.RECONCILE_THRESHOLD:
		return

	correction_count += 1
	var visual_pos: Vector3 = local_player.global_position + correction_offset

	# Snap to server authoritative state
	local_player.global_position = server_state.position
	local_player.velocity = server_state.velocity
	local_player.on_ground = server_state.get_flag(NetSnapshot.FLAG_ON_GROUND)
	local_player.is_ducked = server_state.get_flag(NetSnapshot.FLAG_IS_DUCKED)

	# Replay inputs from snap_tick+1 to current client_tick
	var saved_test_driven: bool = local_player.test_driven
	local_player.test_driven = true

	for replay_tick in range(snap_tick + 1, client_tick + 1):
		var cmd := _find_input(replay_tick)
		if cmd == null:
			continue
		local_player.apply_network_input(cmd.yaw, cmd.pitch,
			cmd.has_button(NetInput.BIT_FORWARD), cmd.has_button(NetInput.BIT_BACK),
			cmd.has_button(NetInput.BIT_LEFT), cmd.has_button(NetInput.BIT_RIGHT),
			cmd.has_button(NetInput.BIT_JUMP), cmd.has_button(NetInput.BIT_DUCK),
			cmd.has_button(NetInput.BIT_WALK))
		local_player.simulate_tick(NetConstants.TICK_INTERVAL)

	local_player.test_driven = saved_test_driven

	# Visual smoothing: offset decays over RECONCILE_SMOOTH_TIME
	correction_origin = visual_pos - local_player.global_position
	correction_offset = correction_origin
	correction_timer = NetConstants.RECONCILE_SMOOTH_TIME

	local_player.reset_physics_interpolation()

	if correction_count <= 10 or correction_count % 50 == 0:
		print("[Client] Correction #%d: error=%.3fm, replayed %d ticks" % [
			correction_count, error, client_tick - snap_tick])


func _handle_event(packet: PackedByteArray) -> void:
	if packet.size() < 3:
		return
	var evt_type: int = packet[2]
	match evt_type:
		NetProtocol.EVT_KILL:
			if packet.size() >= 9:
				var killer_id := packet[3] | (packet[4] << 8)
				var victim_id := packet[5] | (packet[6] << 8)
				var weapon_byte := packet[7]
				var headshot := (weapon_byte & 0x80) != 0
				var weapon_idx := weapon_byte & 0x7F
				var kill_flags := packet[8]
				_track_kill(killer_id, victim_id)
				var killer_team := _get_player_team(killer_id)
				var victim_team := _get_player_team(victim_id)
				KillFeed.add_kill(killer_id, victim_id, weapon_idx, headshot,
					kill_flags, killer_team, victim_team, my_peer_id)
				if killer_id == my_peer_id:
					SoundManager.play_hit_confirm(headshot)
				if victim_id == my_peer_id:
					SoundManager.play_death()
					if spectator and local_player:
						var head := local_player.get_node("Head")
						spectator.enter_deathcam(
							head.global_position,
							local_player.rotation.y,
							head.rotation.x)
						local_player.set_process_unhandled_input(false)
				print("[Client] KILL: Player %d killed Player %d%s" % [
					killer_id, victim_id, " (HEADSHOT)" if headshot else ""])
		NetProtocol.EVT_HIT:
			if packet.size() >= 7:
				var victim_id := packet[3] | (packet[4] << 8)
				var damage := packet[5]
				var headshot := packet[6] != 0
				SoundManager.play_hit_confirm(headshot)
				print("[Client] HIT: Player %d for %d dmg%s" % [
					victim_id, damage, " (HEADSHOT)" if headshot else ""])
		NetProtocol.EVT_SESSION:
			if packet.size() >= 7:
				session_token = packet[3] | (packet[4] << 8) | (packet[5] << 16) | (packet[6] << 24)
				print("[Client] Session token: %d" % session_token)
		NetProtocol.EVT_CHAT:
			if packet.size() >= 8:
				var sender_id := packet[3] | (packet[4] << 8)
				var team_flag := packet[5] != 0
				var msg_len := packet[6] | (packet[7] << 8)
				if packet.size() >= 8 + msg_len:
					var msg := packet.slice(8, 8 + msg_len).get_string_from_utf8()
					if chat:
						chat.on_chat_received(sender_id, msg, team_flag)
					print("[Chat] %sPlayer %d: %s" % [
						"(TEAM) " if team_flag else "", sender_id, msg])
		NetProtocol.EVT_SERVER_MSG:
			if packet.size() >= 5:
				var msg_len := packet[3] | (packet[4] << 8)
				if packet.size() >= 5 + msg_len:
					var msg := packet.slice(5, 5 + msg_len).get_string_from_utf8()
					if chat:
						chat.on_server_message(msg)
					print("[Server] %s" % msg)
		NetProtocol.EVT_MATCH_STATE:
			var ms := NetProtocol.unpack_match_state_event(packet)
			if not ms.is_empty():
				mode_loader.apply_match_state(ms["mode"], ms["state"])
				var st: Dictionary = ms["state"]
				var my_team: int = st.get("my_team", 0)
				var atk_team: int = st.get("attack_team", 0)
				var my_money: int = st.get("money", 0)
				buy_menu.update_money(my_money)
				buy_menu.update_state(my_team, atk_team, 0, 0)
				if hud:
					hud.my_peer_id = my_peer_id
					hud.update_from_match_state(st)
				ClientScoreboard.my_peer_id = my_peer_id
				ClientScoreboard.update_mode(ms["mode"])
				ClientScoreboard.update_from_match_state(st)
				if spectator:
					spectator.my_peer_id = my_peer_id
					spectator.my_team = my_team
					spectator.game_mode = ms["mode"]
					spectator.update_roster(st.get("roster", []))
				if team_select:
					var tc: Dictionary = st.get("team_counts", {})
					team_select.update_counts(
						tc.get(Team.Id.ANGELS, 0),
						tc.get(Team.Id.DEMONS, 0))
					if not _team_select_shown and ms["mode"] == &"competitive":
						_team_select_shown = true
						team_select.open_menu()
				if interpolation:
					_update_team_colors(st.get("roster", []))
		NetProtocol.EVT_SPAWN:
			if packet.size() >= 17:
				var spawned_id := packet[3] | (packet[4] << 8)
				var px := NetSnapshot._read_i32_s(packet, 5)
				var py := NetSnapshot._read_i32_s(packet, 9)
				var pz := NetSnapshot._read_i32_s(packet, 13)
				var pos := Vector3(float(px), float(py), float(pz)) * NetConstants.POS_PRECISION
				if spawned_id == my_peer_id and local_player:
					local_player.global_position = pos
					local_player.velocity = Vector3.ZERO
					prediction_buffer.clear()
					if death_report and death_report.is_showing():
						death_report.hide_report()
					if spectator and spectator.is_spectating():
						spectator.exit_spectator()
						local_player.set_process_unhandled_input(true)
						var cam := local_player.get_node_or_null("Head/Camera3D")
						if cam:
							cam.current = true
				print("[Client] SPAWN: Player %d at %s" % [spawned_id, pos])
		NetProtocol.EVT_BUY_RESULT:
			if packet.size() >= 7:
				var success := packet[3] != 0
				var item_idx := packet[4]
				var new_money := packet[5] | (packet[6] << 8)
				buy_menu.update_money(new_money)
				var item := BuyCatalog.get_item(item_idx)
				if success and not item.is_empty():
					print("[Client] Bought %s (money: $%d)" % [item["name"], new_money])
				elif not item.is_empty():
					print("[Client] Buy failed: %s" % item["name"])
		NetProtocol.EVT_BUY_REQUEST:
			if packet.size() >= 6:
				var requester_id := packet[3] | (packet[4] << 8)
				var item_idx := packet[5]
				buy_menu.show_request(requester_id, item_idx)
				if not buy_menu.is_open:
					buy_menu.open_menu()
		NetProtocol.EVT_DEATH_REPORT:
			var dr := NetProtocol.unpack_death_report_event(packet)
			if not dr.is_empty() and dr["victim_id"] == my_peer_id:
				if death_report:
					death_report.show_report(dr["report"])
				print("[Client] Death report: gave=%d took=%d" % [
					dr["report"].get("given", []).size(),
					dr["report"].get("taken", []).size()])
		NetProtocol.EVT_GRENADE_SPAWN:
			if packet.size() >= 36:
				var g_thrower := packet[3] | (packet[4] << 8)
				var _g_id := packet[5] | (packet[6] << 8)
				var g_type: int = packet[7]
				var g_pos := Vector3(
					packet.decode_float(8),
					packet.decode_float(12),
					packet.decode_float(16))
				var g_vel := Vector3(
					packet.decode_float(20),
					packet.decode_float(24),
					packet.decode_float(28))
				var g_fuse: float = packet.decode_float(32)
				if g_thrower != my_peer_id:
					_spawn_remote_grenade(g_type, g_pos, g_vel, g_fuse)
				print("[Client] GRENADE: Player %d threw type=%d" % [g_thrower, g_type])
		NetProtocol.EVT_GRENADE_DETONATE:
			if packet.size() >= 18:
				var _det_id := packet[3] | (packet[4] << 8)
				var det_type: int = packet[5]
				var det_pos := Vector3(
					packet.decode_float(6),
					packet.decode_float(10),
					packet.decode_float(14))
				_on_grenade_detonate(det_type, det_pos)
		NetProtocol.EVT_FLASH:
			if packet.size() >= 11:
				var blind_time: float = packet.decode_float(3)
				var fade_time: float = packet.decode_float(7)
				if local_player and local_player.has_method("apply_flash"):
					local_player.apply_flash(blind_time, fade_time)
				print("[Client] FLASHED: blind=%.1f fade=%.1f" % [blind_time, fade_time])


func set_local_player(player: CharacterBody3D) -> void:
	local_player = player
	local_player.test_driven = true
	local_player.is_local_client = true
	local_player.set_physics_process(false)
	local_player.set_physics_interpolation_mode(Node.PHYSICS_INTERPOLATION_MODE_OFF)


func _compute_tick_lead() -> int:
	var rtt_ms := 10.0
	if NetworkManager.peer:
		var server_peer := NetworkManager.peer.get_peer(1)
		if server_peer:
			rtt_ms = maxf(float(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)), 1.0)
	var rtt_ticks := int(ceil(rtt_ms / (NetConstants.TICK_INTERVAL * 1000.0)))
	return maxi(3, rtt_ticks + 2)


func _track_kill(killer_id: int, victim_id: int) -> void:
	if not player_stats.has(killer_id):
		player_stats[killer_id] = {"kills": 0, "deaths": 0}
	if not player_stats.has(victim_id):
		player_stats[victim_id] = {"kills": 0, "deaths": 0}
	player_stats[killer_id]["kills"] += 1
	player_stats[victim_id]["deaths"] += 1


func _update_team_colors(roster: Array) -> void:
	for entry in roster:
		_team_map[entry.get("id", 0)] = entry.get("team", 0)
	for pid in interpolation.remote_players:
		var rp: Dictionary = interpolation.remote_players[pid]
		var team: int = _team_map.get(pid, Team.Id.UNASSIGNED)
		rp["node"].set_team_color(Team.get_color(team))


func _get_player_team(peer_id: int) -> int:
	return _team_map.get(peer_id, Team.Id.UNASSIGNED)


func _setup_reconnect_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "ReconnectOverlay"
	overlay.layer = 20
	add_child(overlay)

	reconnect_label = Label.new()
	reconnect_label.add_theme_font_size_override("font_size", 28)
	reconnect_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	reconnect_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	reconnect_label.add_theme_constant_override("shadow_offset_x", 2)
	reconnect_label.add_theme_constant_override("shadow_offset_y", 2)
	reconnect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reconnect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reconnect_label.anchors_preset = Control.PRESET_FULL_RECT
	reconnect_label.visible = false
	overlay.add_child(reconnect_label)


func _start_reconnect() -> void:
	reconnecting = true
	reconnect_timer = 0.0
	reconnect_elapsed = 0.0
	reconnect_label.visible = true
	reconnect_label.text = "Reconnecting..."
	NetworkManager.disconnect_from_server()
	print("[Client] Starting reconnect (token=%d)" % session_token)


func _on_buy_requested(item_index: int) -> void:
	var packet := NetProtocol.pack_buy_request(item_index)
	multiplayer.send_bytes(packet, 1,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_ADMIN)


func _on_weapon_requested(item_index: int) -> void:
	var packet := NetProtocol.pack_weapon_request(item_index)
	multiplayer.send_bytes(packet, 1,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_ADMIN)


func _on_team_selected(team: int) -> void:
	var packet := NetProtocol.pack_team_select(team)
	multiplayer.send_bytes(packet, 1,
		MultiplayerPeer.TRANSFER_MODE_RELIABLE,
		NetConstants.CHANNEL_ADMIN)


func _spawn_remote_grenade(grenade_type: int, pos: Vector3, vel: Vector3, fuse: float) -> void:
	var GrenadeProjectile := preload("res://shared/scripts/grenade_projectile.gd")
	var grenade := RigidBody3D.new()
	grenade.set_script(GrenadeProjectile)
	grenade.visual_only = true
	add_child(grenade)
	grenade.global_position = pos
	grenade.linear_velocity = vel
	grenade.start(fuse, grenade_type)


func _on_grenade_detonate(grenade_type: int, pos: Vector3) -> void:
	match grenade_type:
		2:
			var SmokeCloudScript := preload("res://shared/scripts/smoke_cloud.gd")
			var cloud := Node3D.new()
			cloud.set_script(SmokeCloudScript)
			add_child(cloud)
			cloud.global_position = pos


func _attempt_reconnect() -> void:
	NetworkManager.disconnect_from_server()
	var err := NetworkManager.join_server(server_address, server_port)
	if err != OK:
		print("[Client] Reconnect attempt failed: %s" % error_string(err))
