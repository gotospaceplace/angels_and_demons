class_name GrenadeProjectile
extends RigidBody3D

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")

enum Type { HE, FLASH, SMOKE }

var fuse_remaining: float = 0.0
var type: int = Type.HE

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1

	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = WC.GRENADE_BOUNCE
	phys_mat.friction = WC.GRENADE_FRICTION
	physics_material_override = phys_mat

	var project_grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	if project_grav > 0.0:
		gravity_scale = (MC.GRAVITY * 0.4) / project_grav

	linear_damp = 0.1
	angular_damp = 2.0
	continuous_cd = true

	var shape := SphereShape3D.new()
	shape.radius = 0.04
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.2, 0.1)
	mesh.material_override = mat
	add_child(mesh)


func start(fuse: float, grenade_type: int = Type.HE) -> void:
	fuse_remaining = fuse
	type = grenade_type


func _physics_process(delta: float) -> void:
	fuse_remaining -= delta
	if fuse_remaining <= 0.0:
		_detonate()


func _detonate() -> void:
	match type:
		Type.HE:
			_detonate_he()
		Type.FLASH:
			_detonate_flash()
		Type.SMOKE:
			_detonate_smoke()
	queue_free()


func _detonate_he() -> void:
	var blast_radius_m := WC.HE_BLAST_RADIUS_GSRC * MC.METERS_PER_UNIT
	var pos := global_position
	var space := get_world_3d().direct_space_state

	var shape := SphereShape3D.new()
	shape.radius = blast_radius_m
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, pos)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := space.intersect_shape(query, 32)
	var damaged: Dictionary = {}

	for result in results:
		var collider: Object = result["collider"]
		if not collider:
			continue
		var target = collider.get_parent()
		if not target or not target is Node3D:
			continue
		if damaged.has(target):
			continue
		if not target.has_method("take_damage"):
			continue

		var target_pos: Vector3 = target.global_position
		var check_from := pos + Vector3(0, 0.1, 0)
		var check_to := target_pos + Vector3(0, 0.5, 0)
		var los_params := PhysicsRayQueryParameters3D.create(check_from, check_to)
		los_params.collision_mask = 1
		var los_result := space.intersect_ray(los_params)
		if los_result:
			continue

		var dist_m := pos.distance_to(target_pos)
		var dist_gsrc := dist_m * MC.UNITS_PER_METER
		if dist_gsrc >= WC.HE_BLAST_RADIUS_GSRC:
			continue

		var damage := WC.HE_DAMAGE * (1.0 - dist_gsrc / WC.HE_BLAST_RADIUS_GSRC)
		target.take_damage(damage, "chest", "HE Grenade", WC.HE_ARMOR_PEN)
		damaged[target] = true


func _detonate_flash() -> void:
	var pos := global_position
	var space := get_world_3d().direct_space_state

	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if not p is CharacterBody3D:
			continue
		if not p.has_method("apply_flash"):
			continue

		var cam: Camera3D = p.get_node("Head/Camera3D")
		var eye_pos: Vector3 = cam.global_position

		var los_params := PhysicsRayQueryParameters3D.create(
			pos + Vector3(0, 0.1, 0), eye_pos)
		los_params.collision_mask = 1
		los_params.exclude = [p.get_rid()]
		var los_result := space.intersect_ray(los_params)
		if los_result:
			continue

		var cam_forward := -cam.global_transform.basis.z
		var dir_to_flash := pos - eye_pos
		cam_forward.y = 0.0
		dir_to_flash.y = 0.0
		cam_forward = cam_forward.normalized()
		dir_to_flash = dir_to_flash.normalized()
		var dot := cam_forward.dot(dir_to_flash)
		var angle_deg := rad_to_deg(acos(clampf(dot, -1.0, 1.0)))

		var blind := _lerp_by_angle(angle_deg, WC.FLASH_ANGLES, WC.FLASH_BLIND)
		var fade := _lerp_by_angle(angle_deg, WC.FLASH_ANGLES, WC.FLASH_FADE)

		if blind <= 0.0 and fade <= 0.0:
			fade = WC.FLASH_TINT_TIME
		if blind <= 0.0 and fade <= 0.0:
			continue

		p.apply_flash(blind, fade)


func _detonate_smoke() -> void:
	var cloud := Node3D.new()
	cloud.set_script(preload("res://shared/scripts/smoke_cloud.gd"))
	get_parent().add_child(cloud)
	cloud.global_position = global_position


func _lerp_by_angle(angle: float, angles: Array, values: Array) -> float:
	if angle <= float(angles[0]):
		return float(values[0])
	for i in range(1, angles.size()):
		if angle <= float(angles[i]):
			var t: float = (angle - float(angles[i - 1])) / (float(angles[i]) - float(angles[i - 1]))
			return lerpf(float(values[i - 1]), float(values[i]), t)
	return float(values[values.size() - 1])
