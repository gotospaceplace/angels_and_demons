extends Node3D

const MC = preload("res://shared/scripts/movement_constants.gd")

var peer_id: int = 0
var head: Node3D
var name_label: Label3D
var character_model: CharacterModel
var _prev_position := Vector3.ZERO
var _has_prev := false


func create(p_peer_id: int) -> void:
	peer_id = p_peer_id
	name = "RemotePlayer_%d" % peer_id

	head = Node3D.new()
	head.name = "Head"
	head.position.y = MC.VIEW_OFFSET_STANDING
	add_child(head)

	character_model = CharacterModel.new()
	character_model.name = "CharacterModel"
	add_child(character_model)
	character_model.setup("angels")

	name_label = Label3D.new()
	name_label.text = "Player %d" % peer_id
	name_label.font_size = 28
	name_label.pixel_size = 0.005
	name_label.position.y = MC.HULL_STANDING_HEIGHT * 0.5 + 0.3
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	add_child(name_label)


func set_team_color(color: Color) -> void:
	if character_model:
		character_model.set_team_color(color)


func apply_state(pos: Vector3, yaw_deg: float, pitch_deg: float, ducked: bool) -> void:
	global_position = pos
	rotation.y = deg_to_rad(yaw_deg)
	head.rotation.x = clampf(deg_to_rad(pitch_deg), -PI / 2.0, PI / 2.0)

	if ducked:
		head.position.y = MC.VIEW_OFFSET_DUCKING
	else:
		head.position.y = MC.VIEW_OFFSET_STANDING

	if character_model:
		character_model.set_ducked(ducked)

		if _has_prev:
			var dt := get_process_delta_time()
			if dt > 0.001:
				var world_vel := (pos - _prev_position) / dt
				var local_vel := world_vel.rotated(Vector3.UP, -deg_to_rad(yaw_deg))
				var on_ground := absf(world_vel.y) < 1.0
				character_model.update_movement(local_vel, on_ground)
		else:
			character_model.update_movement(Vector3.ZERO, true)

		_prev_position = pos
		_has_prev = true
