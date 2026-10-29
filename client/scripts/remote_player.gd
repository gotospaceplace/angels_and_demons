extends Node3D

const MC = preload("res://shared/scripts/movement_constants.gd")

var peer_id: int = 0
var head: Node3D
var body_mesh: MeshInstance3D
var name_label: Label3D


func create(p_peer_id: int) -> void:
	peer_id = p_peer_id
	name = "RemotePlayer_%d" % peer_id

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = MC.HULL_STANDING_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 0.85)
	capsule.material = mat

	body_mesh = MeshInstance3D.new()
	body_mesh.mesh = capsule
	add_child(body_mesh)

	head = Node3D.new()
	head.name = "Head"
	head.position.y = MC.VIEW_OFFSET_STANDING
	add_child(head)

	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.75, 0.65)
	sphere.material = head_mat
	var head_vis := MeshInstance3D.new()
	head_vis.mesh = sphere
	head.add_child(head_vis)

	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.35)
	var wep_mat := StandardMaterial3D.new()
	wep_mat.albedo_color = Color(0.25, 0.25, 0.25)
	box.material = wep_mat
	var wep_vis := MeshInstance3D.new()
	wep_vis.mesh = box
	wep_vis.position = Vector3(0.25, -0.05, -0.25)
	head.add_child(wep_vis)

	name_label = Label3D.new()
	name_label.text = "Player %d" % peer_id
	name_label.font_size = 28
	name_label.pixel_size = 0.005
	name_label.position.y = MC.HULL_STANDING_HEIGHT * 0.5 + 0.3
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	add_child(name_label)


func apply_state(pos: Vector3, yaw_deg: float, pitch_deg: float, ducked: bool) -> void:
	global_position = pos
	rotation.y = deg_to_rad(yaw_deg)
	head.rotation.x = clampf(deg_to_rad(pitch_deg), -PI / 2.0, PI / 2.0)

	if ducked:
		head.position.y = MC.VIEW_OFFSET_DUCKING
	else:
		head.position.y = MC.VIEW_OFFSET_STANDING
