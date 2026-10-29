extends CanvasLayer

var panel: Panel
var title_label: Label
var header_label: Label
var content_label: Label


func _ready() -> void:
	layer = 10

	panel = Panel.new()
	panel.name = "ScoreboardPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	add_child(panel)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.text = "SCOREBOARD"
	panel.add_child(title_label)

	header_label = Label.new()
	header_label.add_theme_font_size_override("font_size", 16)
	header_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	panel.add_child(header_label)

	content_label = Label.new()
	content_label.add_theme_font_size_override("font_size", 16)
	content_label.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(content_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB:
		panel.visible = event.pressed
		if event.pressed:
			_refresh()


func _process(_delta: float) -> void:
	if panel.visible:
		_refresh()


func _refresh() -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	var pw := 560.0
	var ph := minf(360.0, vp.y * 0.6)
	panel.position = Vector2((vp.x - pw) * 0.5, (vp.y - ph) * 0.5)
	panel.size = Vector2(pw, ph)
	title_label.position = Vector2(0, 10)
	title_label.size = Vector2(pw, 30)
	header_label.position = Vector2(20, 48)
	header_label.size = Vector2(pw - 40, 24)
	content_label.position = Vector2(20, 72)
	content_label.size = Vector2(pw - 40, ph - 82)

	var cg := get_tree().get_first_node_in_group("client_game")
	if not cg:
		content_label.text = "Not connected"
		return

	var known_peers: Dictionary = {}
	if cg.snapshot_buffer.size() > 0:
		var latest: Dictionary = cg.snapshot_buffer[cg.snapshot_buffer.size() - 1]
		for s in latest["states"]:
			known_peers[s.peer_id] = true
	for pid in cg.player_stats:
		known_peers[pid] = true
	if cg.my_peer_id > 0:
		known_peers[cg.my_peer_id] = true

	var entries: Array = []
	for pid in known_peers:
		var stats: Dictionary = cg.player_stats.get(pid, {})
		entries.append({
			"peer_id": pid,
			"kills": stats.get("kills", 0),
			"deaths": stats.get("deaths", 0),
		})
	entries.sort_custom(func(a, b): return a["kills"] > b["kills"])

	var local_ping := _get_local_ping()

	header_label.text = "%-18s %6s %6s %6s %8s" % ["Player", "Kills", "Deaths", "K/D", "Ping"]

	var text := ""
	for entry in entries:
		var pid: int = entry["peer_id"]
		var k: int = entry["kills"]
		var d: int = entry["deaths"]
		var kd_str := "%.1f" % (float(k) / maxf(float(d), 1.0))
		var ping_str: String
		if pid == cg.my_peer_id:
			ping_str = "%d ms" % local_ping
		else:
			ping_str = "---"
		var name_str := "Player %d" % pid
		if pid == cg.my_peer_id:
			name_str += " *"
		text += "%-18s %6d %6d %6s %8s\n" % [name_str, k, d, kd_str, ping_str]

	content_label.text = text


func _get_local_ping() -> int:
	if not NetworkManager.peer:
		return 0
	var server_peer := NetworkManager.peer.get_peer(1)
	if server_peer:
		return int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	return 0
