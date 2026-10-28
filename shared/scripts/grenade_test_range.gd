extends Node3D

const MC := preload("res://shared/scripts/movement_constants.gd")
const DummyScript := preload("res://shared/scripts/target_dummy.gd")

const DISTANCES := [
	{"gsrc": 32, "hp": 90},
	{"gsrc": 135, "hp": 61},
	{"gsrc": 234, "hp": 33},
	{"gsrc": 332, "hp": 5},
]

func _ready() -> void:
	var gz_label := Label3D.new()
	gz_label.text = "GROUND ZERO"
	gz_label.position = Vector3(0, 0.4, 0)
	gz_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gz_label.font_size = 24
	gz_label.outline_size = 5
	gz_label.modulate = Color(1, 0.3, 0.3, 1)
	add_child(gz_label)

	_add_ground_disc(Vector3.ZERO, 0.3, Color(1.0, 0.1, 0.1))

	for d in DISTANCES:
		var dist_m: float = float(d["gsrc"]) / MC.UNITS_PER_METER
		_add_ground_strip(Vector3(0, 0, dist_m), Color(1.0, 0.8, 0.0))

		var label := Label3D.new()
		label.text = "%.1fm (%du) -> %dHP" % [dist_m, d["gsrc"], d["hp"]]
		label.position = Vector3(0.7, 0.8, dist_m)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 16
		label.outline_size = 4
		add_child(label)

		var dummy := Node3D.new()
		dummy.set_script(DummyScript)
		dummy.position = Vector3(0, 0, dist_m)
		add_child(dummy)


func _add_ground_disc(pos: Vector3, radius: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.02
	mesh.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	mesh.position = pos + Vector3(0, 0.01, 0)
	add_child(mesh)


func _add_ground_strip(pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.02, 0.05)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	mesh.position = pos + Vector3(0, 0.01, 0)
	add_child(mesh)
