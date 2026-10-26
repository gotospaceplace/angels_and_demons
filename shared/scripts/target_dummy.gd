extends Node3D

var hp: float = 100.0
var max_hp: float = 100.0
var _label: Label3D
var _reset_timer: float = 0.0


func _ready() -> void:
	_create_hitboxes()
	_create_visual()
	_create_label()


func take_damage(damage: float, hitgroup: String, weapon_name: String) -> void:
	hp = maxf(hp - damage, 0.0)
	var color := Color.RED if hitgroup == "head" else Color.YELLOW
	_label.modulate = color
	_label.text = "%s → %s\n%.1f dmg  (%.0f HP)" % [weapon_name, hitgroup, damage, hp]
	_reset_timer = 3.0


func _process(delta: float) -> void:
	if _reset_timer > 0.0:
		_reset_timer -= delta
		if _reset_timer <= 0.0:
			hp = max_hp
			_label.text = "Target  %.0f HP" % hp
			_label.modulate = Color.WHITE


func _create_hitboxes() -> void:
	# CS player is ~1.829m (72u) tall
	_add_hitbox("head", Vector3(0, 1.6, 0), _sphere(0.15))
	_add_hitbox("chest", Vector3(0, 1.15, 0), _box(Vector3(0.4, 0.45, 0.25)))
	_add_hitbox("stomach", Vector3(0, 0.78, 0), _box(Vector3(0.35, 0.25, 0.22)))
	_add_hitbox("legs", Vector3(0, 0.35, 0), _box(Vector3(0.35, 0.65, 0.25)))


func _add_hitbox(group_name: String, pos: Vector3, shape: Shape3D) -> void:
	var area := Area3D.new()
	area.name = "Hitbox_" + group_name
	area.collision_layer = 8  # Layer 4 = Hitboxes
	area.collision_mask = 0
	area.set_meta("hitgroup", group_name)
	var col := CollisionShape3D.new()
	col.shape = shape
	area.add_child(col)
	area.position = pos
	add_child(area)


func _create_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.5, 0.35)

	# Body
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.height = 1.5
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	body.mesh = cyl
	body.position = Vector3(0, 0.75, 0)
	body.material_override = mat
	add_child(body)

	# Head
	var head := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.15
	sph.height = 0.3
	head.mesh = sph
	head.position = Vector3(0, 1.6, 0)
	head.material_override = mat
	add_child(head)


func _create_label() -> void:
	_label = Label3D.new()
	_label.position = Vector3(0, 2.1, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 32
	_label.outline_size = 4
	_label.modulate = Color.WHITE
	_label.text = "Target  %.0f HP" % hp
	add_child(_label)


func _sphere(r: float) -> SphereShape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


func _box(sz: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = sz
	return b
