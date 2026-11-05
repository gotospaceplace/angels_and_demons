class_name ClientSpectator
extends Node3D

enum Mode { ALIVE, DEATHCAM, FOLLOW, FREECAM }

const MC = preload("res://shared/scripts/movement_constants.gd")
const WEAPON_NAMES := ["Melee", "USP", "AK-47", "M4A1", "AWP"]

const DEATHCAM_DURATION := 2.0
const FREECAM_SPEED := 10.0
const FREECAM_FAST_MULT := 3.0

var mode: int = Mode.ALIVE
var my_peer_id: int = 0
var my_team: int = 0
var game_mode: StringName = &""
var spectate_target: int = 0
var roster: Array = []

var _deathcam_timer: float = 0.0
var _freecam_yaw: float = 0.0
var _freecam_pitch: float = 0.0

var camera: Camera3D
var interpolation = null

# HUD elements
var _hud_layer: CanvasLayer
var _target_label: Label
var _hp_label: Label
var _armor_label: Label
var _weapon_label: Label
var _mode_label: Label
var _hint_label: Label


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "SpectatorCamera"
	camera.fov = 90.0
	camera.current = false
	add_child(camera)
	_build_hud()
	set_process_unhandled_input(false)


func is_spectating() -> bool:
	return mode != Mode.ALIVE


func enter_deathcam(death_pos: Vector3, death_yaw: float, death_pitch: float) -> void:
	mode = Mode.DEATHCAM
	_deathcam_timer = DEATHCAM_DURATION
	global_position = death_pos
	rotation.y = death_yaw
	camera.rotation.x = death_pitch
	camera.current = true
	_hud_layer.visible = true
	_mode_label.text = ""
	_target_label.text = ""
	_hp_label.text = ""
	_armor_label.text = ""
	_weapon_label.text = ""
	_hint_label.visible = false
	set_process_unhandled_input(true)
	print("[Spectator] Deathcam at %s" % death_pos)


func exit_spectator() -> void:
	mode = Mode.ALIVE
	spectate_target = 0
	camera.current = false
	_hud_layer.visible = false
	set_process_unhandled_input(false)
	print("[Spectator] Exited spectator mode")


func update_roster(new_roster: Array) -> void:
	roster = new_roster


func _process(delta: float) -> void:
	match mode:
		Mode.DEATHCAM:
			_deathcam_timer -= delta
			if _deathcam_timer <= 0.0:
				_enter_follow()
		Mode.FOLLOW:
			_update_follow()
		Mode.FREECAM:
			_update_freecam(delta)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.ALIVE:
		return

	if mode == Mode.DEATHCAM:
		return

	if event.is_action_pressed("fire"):
		_cycle_target(1)
		if mode == Mode.FREECAM:
			_enter_follow()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fire_secondary"):
		_cycle_target(-1)
		if mode == Mode.FREECAM:
			_enter_follow()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("jump"):
		if mode == Mode.FOLLOW:
			_enter_freecam()
		else:
			_enter_follow()
		get_viewport().set_input_as_handled()

	if mode == Mode.FREECAM and event is InputEventMouseMotion:
		var sens: float = GameSettings.mouse_sensitivity
		_freecam_yaw -= event.relative.x * sens
		_freecam_pitch = clampf(_freecam_pitch - event.relative.y * sens, -PI / 2.0, PI / 2.0)
		get_viewport().set_input_as_handled()


func _enter_follow() -> void:
	mode = Mode.FOLLOW
	_cycle_target(1)
	if spectate_target == 0:
		_enter_freecam()
		return
	_mode_label.text = "SPECTATING"
	_hint_label.visible = true
	_hint_label.text = "LMB / RMB: Switch player  |  SPACE: Free camera"
	print("[Spectator] Following player %d" % spectate_target)


func _enter_freecam() -> void:
	mode = Mode.FREECAM
	_freecam_yaw = rotation.y
	_freecam_pitch = camera.rotation.x
	spectate_target = 0
	_mode_label.text = "FREE CAMERA"
	_target_label.text = ""
	_hp_label.text = ""
	_armor_label.text = ""
	_weapon_label.text = ""
	_hint_label.visible = true
	_hint_label.text = "WASD: Move  |  SHIFT: Fast  |  LMB / RMB: Follow player"
	print("[Spectator] Free camera")


func _cycle_target(direction: int) -> void:
	var targets := _get_valid_targets()
	if targets.is_empty():
		spectate_target = 0
		return
	var idx := targets.find(spectate_target)
	if idx == -1:
		spectate_target = targets[0]
	else:
		idx = posmod(idx + direction, targets.size())
		spectate_target = targets[idx]


func _get_valid_targets() -> Array:
	if not interpolation:
		return []
	var targets := []
	for pid in interpolation.remote_players:
		if _is_valid_target(pid):
			targets.append(pid)
	targets.sort()
	return targets


func _is_valid_target(pid: int) -> bool:
	if game_mode == &"competitive" and my_team > 0:
		var found := false
		for entry in roster:
			if entry.get("id", -1) == pid:
				found = true
				if entry.get("team", 0) != my_team:
					return false
				if not entry.get("alive", false):
					return false
				break
		if not found:
			return _is_alive_in_interp(pid)
	else:
		return _is_alive_in_interp(pid)
	return true


func _is_alive_in_interp(pid: int) -> bool:
	if not interpolation or not interpolation.remote_players.has(pid):
		return false
	var rp: Dictionary = interpolation.remote_players[pid]
	var states: Array = rp["states"]
	if states.is_empty():
		return false
	return not states[states.size() - 1].get("is_dead", true)


func _update_follow() -> void:
	if not interpolation or spectate_target == 0:
		return
	if not interpolation.remote_players.has(spectate_target):
		_cycle_target(1)
		if spectate_target == 0:
			_enter_freecam()
		return
	if not _is_alive_in_interp(spectate_target):
		_cycle_target(1)
		if spectate_target == 0:
			_enter_freecam()
		return

	var rp: Dictionary = interpolation.remote_players[spectate_target]
	var node: Node3D = rp["node"]
	var head_node: Node3D = node.get_node_or_null("Head")
	if head_node:
		global_position = head_node.global_position
		rotation.y = node.rotation.y
		camera.rotation.x = head_node.rotation.x
	else:
		global_position = node.global_position + Vector3(0, MC.VIEW_OFFSET_STANDING, 0)
		rotation.y = node.rotation.y

	_update_spectator_hud(rp)


func _update_freecam(delta: float) -> void:
	var speed := FREECAM_SPEED
	if Input.is_action_pressed("walk"):
		speed *= FREECAM_FAST_MULT
	rotation.y = _freecam_yaw
	camera.rotation.x = _freecam_pitch
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("jump"):
		input_dir.y += 1.0
	if Input.is_action_pressed("duck"):
		input_dir.y -= 1.0
	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
	global_position += (global_transform.basis * input_dir) * speed * delta


func _update_spectator_hud(rp: Dictionary) -> void:
	_target_label.text = "Player %d" % spectate_target
	var latest: Dictionary = rp.get("latest_snapshot", {})
	if not latest.is_empty():
		_hp_label.text = "%d HP" % latest.get("hp", 0)
		var armor_val: int = latest.get("armor", 0)
		_armor_label.text = "%d AR" % armor_val if armor_val > 0 else ""
		var wep_idx: int = latest.get("weapon_idx", 0)
		if wep_idx >= 0 and wep_idx < WEAPON_NAMES.size():
			_weapon_label.text = "%s  %d" % [WEAPON_NAMES[wep_idx], latest.get("ammo_mag", 0)]
		else:
			_weapon_label.text = "Weapon %d" % wep_idx
	else:
		_hp_label.text = ""
		_armor_label.text = ""
		_weapon_label.text = ""


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "SpectatorHUD"
	_hud_layer.layer = 15
	_hud_layer.visible = false
	add_child(_hud_layer)

	var root := Control.new()
	root.anchors_preset = Control.PRESET_FULL_RECT
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(root)

	_mode_label = Label.new()
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.anchors_preset = Control.PRESET_CENTER_TOP
	_mode_label.position = Vector2(-200, 50)
	_mode_label.size = Vector2(400, 30)
	_mode_label.add_theme_font_size_override("font_size", 18)
	_mode_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.7))
	_mode_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_mode_label.add_theme_constant_override("shadow_offset_x", 1)
	_mode_label.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_mode_label)

	var bottom := VBoxContainer.new()
	bottom.anchors_preset = Control.PRESET_CENTER_BOTTOM
	bottom.position = Vector2(-250, -120)
	bottom.size = Vector2(500, 100)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)

	_target_label = Label.new()
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.add_theme_font_size_override("font_size", 22)
	_target_label.add_theme_color_override("font_color", Color.WHITE)
	_target_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_target_label.add_theme_constant_override("shadow_offset_x", 1)
	_target_label.add_theme_constant_override("shadow_offset_y", 1)
	bottom.add_child(_target_label)

	var stats_row := HBoxContainer.new()
	stats_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_row.add_theme_constant_override("separation", 20)
	bottom.add_child(stats_row)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_hp_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_row.add_child(_hp_label)

	_armor_label = Label.new()
	_armor_label.add_theme_font_size_override("font_size", 18)
	_armor_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	_armor_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_armor_label.add_theme_constant_override("shadow_offset_x", 1)
	_armor_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_row.add_child(_armor_label)

	_weapon_label = Label.new()
	_weapon_label.add_theme_font_size_override("font_size", 18)
	_weapon_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_weapon_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_weapon_label.add_theme_constant_override("shadow_offset_x", 1)
	_weapon_label.add_theme_constant_override("shadow_offset_y", 1)
	stats_row.add_child(_weapon_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.5))
	_hint_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.visible = false
	bottom.add_child(_hint_label)
