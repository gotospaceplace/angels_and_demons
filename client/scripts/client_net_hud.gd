extends CanvasLayer

var net_label: Label
var status_label: Label
var visible_net := true

var update_timer := 0.0
const UPDATE_INTERVAL := 0.1

# Snapshot rate measurement
var last_snap_count := 0
var snap_rate_timer := 0.0
var snapshot_rate := 0.0

# Correction rate (last 10s window)
var correction_timestamps: Array = []
var last_correction_count := 0


func _ready() -> void:
	layer = 9

	net_label = Label.new()
	net_label.add_theme_font_size_override("font_size", 16)
	net_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	net_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	net_label.add_theme_constant_override("shadow_offset_x", 1)
	net_label.add_theme_constant_override("shadow_offset_y", 1)
	net_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(net_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_net_hud"):
		visible_net = not visible_net
		net_label.visible = visible_net


func _process(delta: float) -> void:
	var cg := get_tree().get_first_node_in_group("client_game")

	snap_rate_timer += delta
	if snap_rate_timer >= 1.0:
		if cg:
			var cur: int = cg.snapshots_received
			snapshot_rate = float(cur - last_snap_count) / snap_rate_timer
			last_snap_count = cur
		snap_rate_timer = 0.0

	if cg:
		var cc: int = cg.correction_count
		if cc > last_correction_count:
			var now := Time.get_ticks_msec() * 0.001
			for _i in range(cc - last_correction_count):
				correction_timestamps.append(now)
			last_correction_count = cc

	var now := Time.get_ticks_msec() * 0.001
	while correction_timestamps.size() > 0 and correction_timestamps[0] < now - 10.0:
		correction_timestamps.pop_front()

	update_timer += delta
	if update_timer < UPDATE_INTERVAL:
		return
	update_timer = 0.0

	_update_status(cg)
	if visible_net:
		_update_net(cg)


func _update_net(cg: Node) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	net_label.position = Vector2(vp.x - 260, 16)
	net_label.size = Vector2(244, 200)

	if not cg:
		net_label.text = ""
		return

	var rtt := 0
	var loss_pct := 0.0
	if NetworkManager.peer:
		var server_peer := NetworkManager.peer.get_peer(1)
		if server_peer:
			rtt = int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			var loss_raw := server_peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)
			loss_pct = loss_raw / 65536.0 * 100.0

	var tick_delta: int = cg.client_tick - cg.server_tick

	var text := "--- NET ---\n"
	text += "RTT: %d ms\n" % rtt
	text += "Loss: %.1f%%\n" % loss_pct
	text += "Interp: %d ms\n" % int(NetConstants.INTERP_DELAY_MS)
	text += "Corrections: %d /10s\n" % correction_timestamps.size()
	text += "Snap rate: %.0f Hz\n" % snapshot_rate
	text += "Tick delta: %d\n" % tick_delta
	net_label.text = text


func _update_status(cg: Node) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	status_label.position = Vector2(0, vp.y - 50)
	status_label.size = Vector2(vp.x, 40)

	if not cg or cg.my_peer_id <= 0:
		status_label.text = ""
		return

	var hp := 100
	var armor := 0
	var ammo := 30
	var weapon_idx := 2
	var is_dead := false

	if cg.snapshot_buffer.size() > 0:
		var latest: Dictionary = cg.snapshot_buffer[cg.snapshot_buffer.size() - 1]
		for s in latest["states"]:
			if s.peer_id == cg.my_peer_id:
				hp = s.hp
				armor = s.armor
				ammo = s.ammo_mag
				weapon_idx = s.weapon_idx
				is_dead = s.get_flag(NetSnapshot.FLAG_IS_DEAD)
				break

	var weapon_names := ["Knife", "USP", "AK-47", "M4A1", "AWP"]
	var wname: String = weapon_names[weapon_idx] if weapon_idx < weapon_names.size() else "???"

	if is_dead:
		status_label.text = "*** DEAD ***"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		status_label.text = "HP: %d  |  Armor: %d  |  %s: %d" % [hp, armor, wname, ammo]
		if hp <= 25:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		elif hp <= 50:
			status_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
		else:
			status_label.add_theme_color_override("font_color", Color.WHITE)
