class_name SmokeCloud
extends Node3D

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")

var _elapsed: float = 0.0
var _total_time: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _base_radius: float = 0.0

func _ready() -> void:
	_base_radius = WC.SMOKE_RADIUS_GSRC * MC.METERS_PER_UNIT
	_total_time = WC.SMOKE_FADE_IN + WC.SMOKE_DURATION + WC.SMOKE_FADE_OUT

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)

	for i in range(12):
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		var r := _base_radius * rng.randf_range(0.5, 0.9)
		sphere.radius = r
		sphere.height = r * 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		mesh.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.85, 0.85, 0.82, 0.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = mat

		var offset := Vector3(
			rng.randf_range(-_base_radius * 0.4, _base_radius * 0.4),
			rng.randf_range(-0.3, _base_radius * 0.5),
			rng.randf_range(-_base_radius * 0.4, _base_radius * 0.4))
		mesh.position = offset

		add_child(mesh)
		_meshes.append(mesh)


func _process(delta: float) -> void:
	_elapsed += delta

	var alpha: float = 0.0
	if _elapsed < WC.SMOKE_FADE_IN:
		alpha = _elapsed / WC.SMOKE_FADE_IN
	elif _elapsed < WC.SMOKE_FADE_IN + WC.SMOKE_DURATION:
		alpha = 1.0
	elif _elapsed < _total_time:
		var fade_elapsed := _elapsed - WC.SMOKE_FADE_IN - WC.SMOKE_DURATION
		alpha = 1.0 - fade_elapsed / WC.SMOKE_FADE_OUT
	else:
		queue_free()
		return

	var target_alpha := clampf(alpha * 0.7, 0.0, 0.7)
	for mesh in _meshes:
		var mat: StandardMaterial3D = mesh.material_override
		var c := mat.albedo_color
		mat.albedo_color = Color(c.r, c.g, c.b, target_alpha)
