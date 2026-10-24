extends CanvasLayer

var label: Label
var visible_hud := true

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_hud"):
		visible_hud = not visible_hud
		label.visible = visible_hud

func _physics_process(_delta: float) -> void:
	if not visible_hud:
		return

	var player := _find_player()
	if not player:
		label.text = "No player found"
		return

	var hvel := Vector3(player.velocity.x, 0, player.velocity.z)
	var h_speed := hvel.length()
	var v_speed := player.velocity.y
	var total_speed := player.velocity.length()
	var pos := player.global_position

	var ground_str := "GROUND" if player.on_ground else "AIR"
	var jump_str := "J" if player.jump_pressed else "-"
	var h_speed_gsrc: float = h_speed * MovementConstants.UNITS_PER_METER

	var text := ""
	text += "Speed: %.2f m/s  (%.0f u/s)\n" % [h_speed, h_speed_gsrc]
	text += "VSpeed: %.2f m/s\n" % v_speed
	text += "Pos: %.2f, %.2f, %.2f\n" % [pos.x, pos.y, pos.z]
	text += "State: %s  Jump: %s\n" % [ground_str, jump_str]
	text += "MaxSpeed: %.2f m/s\n" % player.max_speed
	text += "Tick: %d fps  (%.1f ms)\n" % [Engine.physics_ticks_per_second, 1000.0 / Engine.physics_ticks_per_second]

	label.text = text

func _find_player() -> CharacterBody3D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody3D
	# Fallback: find by script
	for node in get_tree().get_nodes_in_group(""):
		if node.has_method("_apply_friction"):
			return node as CharacterBody3D
	return null
