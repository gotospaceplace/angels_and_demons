extends Node3D

const MC = preload("res://shared/scripts/movement_constants.gd")

var peer_id: int = 0
var head: Node3D
var name_label: Label3D
var character_model: CharacterModel


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
