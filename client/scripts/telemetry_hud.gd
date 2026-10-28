extends CanvasLayer

const MC := preload("res://shared/scripts/movement_constants.gd")

var label: Label
var visible_hud := true

# Display refresh throttle
var update_timer := 0.0
const UPDATE_INTERVAL := 0.1  # 10 Hz display update

# Peak trackers (reset on ground contact)
var peak_height := 0.0
var jump_start_y := 0.0
var tracking_jump := false
var peak_air_speed := 0.0

# Landing readout (holds values for 1.5s after landing)
var landing_display_timer := 0.0
var last_jump_height := 0.0
var last_air_speed_peak := 0.0

# Cached display values
var display_text := ""

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		visible_hud = not visible_hud
		label.visible = visible_hud

func _physics_process(delta: float) -> void:
	if not visible_hud:
		return

	var player := _find_player()
	if not player:
		label.text = "No player found"
		return

	var hvel := Vector3(player.velocity.x, 0, player.velocity.z)
	var h_speed := hvel.length()
	var full_speed := player.velocity.length()
	var pos := player.global_position

	# Track jump peaks
	if not player.on_ground:
		if not tracking_jump:
			tracking_jump = true
			jump_start_y = pos.y
			peak_height = pos.y
			peak_air_speed = h_speed
		else:
			peak_height = maxf(peak_height, pos.y)
			peak_air_speed = maxf(peak_air_speed, h_speed)
	elif tracking_jump:
		# Just landed
		last_jump_height = peak_height - jump_start_y
		last_air_speed_peak = peak_air_speed
		landing_display_timer = 1.5
		tracking_jump = false

	if landing_display_timer > 0.0:
		landing_display_timer -= delta

	# Throttle display updates
	update_timer += delta
	if update_timer < UPDATE_INTERVAL:
		label.text = display_text
		return
	update_timer = 0.0

	var h_speed_gsrc := h_speed * MC.UNITS_PER_METER
	var ground_str: String
	if player.on_ladder:
		ground_str = "LADDER"
	elif player.on_ground:
		ground_str = "GROUND"
	else:
		ground_str = "AIR"
	if player.is_ducked:
		ground_str += " DUCK"

	var text := ""
	if player.on_ladder:
		var full_speed_gsrc := full_speed * MC.UNITS_PER_METER
		text += "Speed: %6.1f u/s  (%4.2f m/s) [3D]\n" % [full_speed_gsrc, full_speed]
	else:
		text += "Speed: %6.1f u/s  (%4.2f m/s)\n" % [h_speed_gsrc, h_speed]
	text += "VSpeed: %+.2f m/s\n" % player.velocity.y
	text += "State: %s\n" % ground_str
	if player.hop_count > 0:
		text += "Bhop: %d hops\n" % player.hop_count
	text += "Pos: %.1f, %.1f, %.1f\n" % [pos.x, pos.y, pos.z]

	if player.tag_timer > 0.0:
		text += "TAGGED (%.1fs)\n" % player.tag_timer

	if tracking_jump:
		var cur_height := pos.y - jump_start_y
		var peak := peak_height - jump_start_y
		text += "Jump: %.3fm (peak %.3fm)\n" % [cur_height, peak]
		text += "Air peak: %.0f u/s\n" % (peak_air_speed * MC.UNITS_PER_METER)
	elif landing_display_timer > 0.0:
		text += "Last jump: %.3fm\n" % last_jump_height
		text += "Last air peak: %.0f u/s\n" % (last_air_speed_peak * MC.UNITS_PER_METER)

	# --- Weapon telemetry ---
	var ws := _find_weapon_system()
	if ws:
		text += "\n--- WEAPON ---\n"
		text += "Weapon: %s" % ws.get_weapon_name()
		if ws.silencer_on:
			text += " [S]"
		text += "\n"
		text += "Ammo: %s\n" % ws.get_ammo_display()
		text += "Spread: %.4f\n" % ws.get_current_spread()
		text += "Accuracy: %.3f  Shots: %d\n" % [ws.accuracy, ws.shots_fired]
		text += "Viewpunch: %.2f, %.2f\n" % [ws.viewpunch.x, ws.viewpunch.y]

		if ws.is_grenade_mode:
			text += "Grenade: %s x%d\n" % [ws._get_grenade_name(), ws._grenade_count(ws.current_grenade)]
			if ws.is_cooking:
				text += "Cook: %.1fs\n" % ws.cook_timer

		if ws.last_hit_group != "":
			text += "\n--- LAST HIT ---\n"
			text += "%s → %s\n" % [ws.last_hit_weapon, ws.last_hit_group]
			text += "Damage: %.1f  Dist: %.0fu\n" % [ws.last_hit_damage, ws.last_hit_distance]

		var dps: float = ws.get_dps()
		if dps > 0.0:
			text += "DPS (5s): %.0f\n" % dps

	display_text = text
	label.text = display_text


func _find_weapon_system() -> Node:
	var ws_nodes := get_tree().get_nodes_in_group("weapon_system")
	if ws_nodes.size() > 0:
		return ws_nodes[0]
	return null


func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	return null
