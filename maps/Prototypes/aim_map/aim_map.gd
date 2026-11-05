extends Node3D

## BSP-imported aim_map — GoldSrc BSP30 → Godot 4.7 conversion (Phase 2A).
## Coordinate contract: Godot XYZ = ((BSP_X - center_x), (BSP_Z + 467), -(BSP_Y - center_y)) * 0.0254
## Floor baseline corrected to BSP Z = -467; geometry centered on XZ origin.

var spawn_points: Array[Vector3] = []
var angels_spawns: Array[Vector3] = []
var demons_spawns: Array[Vector3] = []
var portal_sites: Dictionary = {}

var _angels_raw: Array[Vector3] = [
	Vector3(-1.8161, 1.1176, 17.78),
	Vector3(-5.0673, 0.9144, 17.78),
	Vector3(-8.3185, 0.9144, 17.78),
	Vector3(1.4351, 1.1176, 14.5288),
	Vector3(1.0287, 1.1176, 16.1544),
	Vector3(1.4351, 1.1176, 17.78),
	Vector3(1.4351, 1.1176, 19.4056),
	Vector3(-1.8161, 0.9144, 19.4056),
	Vector3(-1.8161, 0.9144, 16.1544),
	Vector3(-1.8161, 0.9144, 14.5288),
	Vector3(-5.0673, 0.9144, 14.5288),
	Vector3(-5.0673, 0.9144, 16.1544),
	Vector3(-5.0673, 0.9144, 19.4056),
	Vector3(-8.3185, 0.9144, 19.4056),
	Vector3(-8.3185, 0.9144, 16.1544),
	Vector3(-8.3185, 0.9144, 14.5288),
]

var _demons_raw: Array[Vector3] = [
	Vector3(8.5471, 0.9144, -14.5034),
	Vector3(8.5471, 0.9144, -16.129),
	Vector3(8.5471, 0.9144, -19.3802),
	Vector3(5.2959, 0.9144, -19.3802),
	Vector3(5.2959, 0.9144, -16.129),
	Vector3(5.2959, 0.9144, -14.5034),
	Vector3(2.0447, 0.9144, -14.5034),
	Vector3(2.0447, 0.9144, -16.129),
	Vector3(2.0447, 0.9144, -19.3802),
	Vector3(-1.2065, 1.1176, -19.3802),
	Vector3(-1.2065, 1.1176, -17.7546),
	Vector3(-1.2065, 1.1176, -16.129),
	Vector3(-1.2065, 1.1176, -14.5034),
	Vector3(8.5471, 0.9144, -17.7546),
	Vector3(5.2959, 0.9144, -17.7546),
	Vector3(2.0447, 1.1176, -17.7546),
]


func _ready() -> void:
	angels_spawns = _angels_raw.duplicate()
	demons_spawns = _demons_raw.duplicate()
	spawn_points = _angels_raw.duplicate()
	spawn_points.append_array(_demons_raw)

	_load_geometry()
	_build_lighting()


func _load_geometry() -> void:
	var glb_scene: PackedScene = load("res://maps/Prototypes/aim_map/geometry/aim_map.glb")
	if glb_scene == null:
		push_error("[AimMap] Failed to load aim_map.glb")
		return
	var world := glb_scene.instantiate()
	world.name = "WorldGeometry"
	add_child(world)

	_generate_collision(world)


func _generate_collision(world: Node3D) -> void:
	for child in world.get_children():
		if child is MeshInstance3D:
			_add_trimesh_collision(child)
		for grandchild in child.get_children():
			if grandchild is MeshInstance3D:
				_add_trimesh_collision(grandchild)


func _add_trimesh_collision(mesh_inst: MeshInstance3D) -> void:
	var mesh := mesh_inst.mesh
	if mesh == null:
		return
	var shape := mesh.create_trimesh_shape()
	if shape == null:
		return
	var body := StaticBody3D.new()
	body.name = mesh_inst.name + "_col"
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	body.global_transform = mesh_inst.global_transform
	add_child(body)


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
