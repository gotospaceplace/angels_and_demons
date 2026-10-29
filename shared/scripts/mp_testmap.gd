extends Node3D

var spawn_points: Array[Vector3] = [
	Vector3(-15, 1, -15),
	Vector3(15, 1, -15),
	Vector3(-15, 1, 15),
	Vector3(15, 1, 15),
	Vector3(0, 1, -17),
	Vector3(0, 1, 17),
	Vector3(-17, 1, 0),
	Vector3(17, 1, 0),
]


func _ready() -> void:
	_build_floor()
	_build_outer_walls()
	_build_pillars()
	_build_platforms()
	_build_corridor()
	_build_crates()
	_build_lighting()


func _build_floor() -> void:
	_add_box("Floor", Vector3(0, -0.1, 0), Vector3(44, 0.2, 44), Color(0.35, 0.35, 0.32))


func _build_outer_walls() -> void:
	var h := 5.0
	var t := 0.5
	var half := 22.0
	_add_box("WallNorth", Vector3(0, h * 0.5, -half), Vector3(44, h, t), Color(0.45, 0.42, 0.38))
	_add_box("WallSouth", Vector3(0, h * 0.5, half), Vector3(44, h, t), Color(0.45, 0.42, 0.38))
	_add_box("WallWest", Vector3(-half, h * 0.5, 0), Vector3(t, h, 44), Color(0.42, 0.40, 0.36))
	_add_box("WallEast", Vector3(half, h * 0.5, 0), Vector3(t, h, 44), Color(0.42, 0.40, 0.36))


func _build_pillars() -> void:
	var s := 1.5
	var h := 4.0
	var d := 7.0
	var color := Color(0.55, 0.50, 0.45)
	_add_box("PillarNW", Vector3(-d, h * 0.5, -d), Vector3(s, h, s), color)
	_add_box("PillarNE", Vector3(d, h * 0.5, -d), Vector3(s, h, s), color)
	_add_box("PillarSW", Vector3(-d, h * 0.5, d), Vector3(s, h, s), color)
	_add_box("PillarSE", Vector3(d, h * 0.5, d), Vector3(s, h, s), color)


func _build_platforms() -> void:
	var plat_h := 2.0
	var color := Color(0.48, 0.45, 0.40)
	var ramp_color := Color(0.50, 0.47, 0.42)

	# North platform
	_add_box("PlatformNorth", Vector3(0, plat_h * 0.5, -14), Vector3(8, plat_h, 5), color)
	# Ramp facing south (toward center)
	_add_ramp("RampNorthS", Vector3(0, 0, -11), plat_h, 3.0, 3.0, false, ramp_color)

	# South platform
	_add_box("PlatformSouth", Vector3(0, plat_h * 0.5, 14), Vector3(8, plat_h, 5), color)
	# Ramp facing north (toward center)
	_add_ramp("RampSouthN", Vector3(0, 0, 11), plat_h, 3.0, 3.0, true, ramp_color)


func _build_corridor() -> void:
	var wall_h := 3.5
	var wall_t := 0.4
	var color := Color(0.50, 0.46, 0.40)
	# East-west corridor through center, 3m wide gap
	_add_box("CorridorWallN", Vector3(0, wall_h * 0.5, -1.5), Vector3(6, wall_h, wall_t), color)
	_add_box("CorridorWallS", Vector3(0, wall_h * 0.5, 1.5), Vector3(6, wall_h, wall_t), color)


func _build_crates() -> void:
	var s := 1.2
	var color := Color(0.6, 0.45, 0.25)
	_add_box("CrateA", Vector3(-10, s * 0.5, -5), Vector3(s, s, s), color)
	_add_box("CrateB", Vector3(10, s * 0.5, -5), Vector3(s, s, s), color)
	_add_box("CrateC", Vector3(-10, s * 0.5, 5), Vector3(s, s, s), color)
	_add_box("CrateD", Vector3(10, s * 0.5, 5), Vector3(s, s, s), color)
	_add_box("CrateE", Vector3(-5, s * 0.5, -10), Vector3(s, s, s), color)
	_add_box("CrateF", Vector3(5, s * 0.5, -10), Vector3(s, s, s), color)
	_add_box("CrateG", Vector3(-5, s * 0.5, 10), Vector3(s, s, s), color)
	_add_box("CrateH", Vector3(5, s * 0.5, 10), Vector3(s, s, s), color)


func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	env.name = "Environment"
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.4, 0.5, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.65, 0.7)
	e.ambient_light_energy = 0.5
	env.environment = e
	add_child(env)


func _add_box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	body.add_child(mesh_inst)

	add_child(body)


func _add_ramp(node_name: String, base_pos: Vector3, height: float, width: float, depth: float, flip: bool, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = base_pos + Vector3(0, height * 0.5, 0)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.15, depth / cos(atan2(height, depth)))
	col.shape = shape
	var angle := atan2(height, depth)
	if flip:
		angle = -angle
	col.rotation.x = angle
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = shape.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.rotation.x = angle
	body.add_child(mesh_inst)

	add_child(body)
