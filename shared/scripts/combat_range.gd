extends Node3D

const MC := preload("res://shared/scripts/movement_constants.gd")
const DummyScript := preload("res://shared/scripts/target_dummy.gd")
const GrenadeRangeScript := preload("res://shared/scripts/grenade_test_range.gd")

var _weapon_rack_label: Label3D
var _rack_area: Area3D

func _ready() -> void:
	_build_firing_lane()
	_build_spray_wall()
	_build_pen_test()
	_build_smoke_corridor()
	_build_flash_room()
	_build_grenade_area()
	_build_weapon_rack()
	_build_section_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_try_weapon_rack()


func _try_weapon_rack() -> void:
	if not _rack_area:
		return
	var bodies := _rack_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			_refill_player(body)
			return


func _refill_player(player: CharacterBody3D) -> void:
	var ws_nodes := get_tree().get_nodes_in_group("weapon_system")
	if ws_nodes.size() == 0:
		return
	var ws: Node = ws_nodes[0]
	ws.grenade_he_count = 1
	ws.grenade_flash_count = 2
	ws.grenade_smoke_count = 1
	if ws.has_method("reload_full"):
		ws.reload_full()
	_weapon_rack_label.text = "WEAPON RACK [E]\nRefilled!"
	get_tree().create_timer(1.5).timeout.connect(func():
		_weapon_rack_label.text = "WEAPON RACK [E]\nRefill ammo + grenades")


# --- Firing lane: targets at 5m, 15m, 30m, 50m ---

func _build_firing_lane() -> void:
	var lane_x := 0.0
	var distances := [5.0, 15.0, 30.0, 50.0]

	_add_label(Vector3(lane_x, 2.5, 2.0), "FIRING RANGE", 48, Color(1, 0.9, 0.3))

	for dist in distances:
		var z: float = -float(dist)
		var gsrc: float = float(dist) * MC.UNITS_PER_METER

		# Unarmored target
		var dummy := Node3D.new()
		dummy.set_script(DummyScript)
		dummy.position = Vector3(lane_x - 1.0, 0.1, z)
		add_child(dummy)

		# Armored target (vest + helmet)
		var armored := Node3D.new()
		armored.set_script(DummyScript)
		armored.position = Vector3(lane_x + 1.0, 0.1, z)
		armored.set("armor_value", 100.0)
		armored.set("has_helmet", true)
		add_child(armored)

		# Distance marker
		_add_ground_strip(Vector3(lane_x, 0.01, z), 4.0, Color(1.0, 0.8, 0.0))
		_add_label(Vector3(lane_x + 2.5, 1.0, z), "%dm (%du)" % [int(dist), int(gsrc)], 24, Color(1, 0.8, 0))


# --- Spray wall ---

func _build_spray_wall() -> void:
	var wall_pos := Vector3(8.0, 1.5, -5.0)
	var wall := _add_box(wall_pos, Vector3(0.3, 3.0, 6.0), Color(0.9, 0.9, 0.85))
	wall.name = "SprayWall"
	_add_label(Vector3(8.0, 3.5, -5.0), "SPRAY WALL", 40, Color(0.9, 0.9, 0.85))


# --- Wall pen test ---

func _build_pen_test() -> void:
	var base_x := -8.0
	var base_z := -5.0

	_add_label(Vector3(base_x, 2.5, base_z + 2.0), "WALL PEN TEST", 40, Color(1, 0.6, 0.2))

	# Thin wood cover
	_add_box(Vector3(base_x - 1.5, 0.85, base_z), Vector3(2, 1.5, 0.15), Color(0.6, 0.4, 0.2))
	_add_label(Vector3(base_x - 1.5, 1.8, base_z + 0.3), "THIN 0.15m", 24, Color(0.6, 0.4, 0.2))
	var pen_thin := Node3D.new()
	pen_thin.set_script(DummyScript)
	pen_thin.position = Vector3(base_x - 1.5, 0.1, base_z - 1.5)
	add_child(pen_thin)

	# Thick concrete
	_add_box(Vector3(base_x + 1.5, 0.85, base_z), Vector3(2, 1.5, 0.8), Color(0.3, 0.3, 0.32))
	_add_label(Vector3(base_x + 1.5, 1.8, base_z + 0.5), "THICK 0.8m", 24, Color(0.4, 0.4, 0.42))
	var pen_thick := Node3D.new()
	pen_thick.set_script(DummyScript)
	pen_thick.position = Vector3(base_x + 1.5, 0.1, base_z - 1.5)
	add_child(pen_thick)


# --- Smoke corridor ---

func _build_smoke_corridor() -> void:
	var cx := 12.0
	var cz := -20.0
	var length := 12.0
	var width := 3.0
	var height := 3.0

	_add_label(Vector3(cx, height + 0.5, cz + length / 2.0 + 1.0), "SMOKE CORRIDOR", 40, Color(0.7, 0.7, 0.7))

	# Left wall
	_add_box(Vector3(cx - width / 2.0 - 0.15, height / 2.0, cz), Vector3(0.3, height, length), Color(0.35, 0.35, 0.38))
	# Right wall
	_add_box(Vector3(cx + width / 2.0 + 0.15, height / 2.0, cz), Vector3(0.3, height, length), Color(0.35, 0.35, 0.38))
	# Ceiling
	_add_box(Vector3(cx, height, cz), Vector3(width + 0.6, 0.2, length), Color(0.2, 0.2, 0.22))

	# Target at far end
	var dummy := Node3D.new()
	dummy.set_script(DummyScript)
	dummy.position = Vector3(cx, 0.1, cz - length / 2.0 + 1.0)
	add_child(dummy)


# --- Flash test room ---

func _build_flash_room() -> void:
	var fx := -12.0
	var fz := -20.0
	var room_size := 6.0
	var height := 3.0

	_add_label(Vector3(fx, height + 0.5, fz + room_size / 2.0 + 1.0), "FLASH ROOM", 40, Color(1, 1, 0.5))

	# Walls (open on one side for entry)
	_add_box(Vector3(fx - room_size / 2.0 - 0.15, height / 2.0, fz), Vector3(0.3, height, room_size), Color(0.35, 0.35, 0.38))
	_add_box(Vector3(fx + room_size / 2.0 + 0.15, height / 2.0, fz), Vector3(0.3, height, room_size), Color(0.35, 0.35, 0.38))
	_add_box(Vector3(fx, height / 2.0, fz - room_size / 2.0 - 0.15), Vector3(room_size + 0.6, height, 0.3), Color(0.35, 0.35, 0.38))
	# Ceiling
	_add_box(Vector3(fx, height, fz), Vector3(room_size + 0.6, 0.2, room_size), Color(0.2, 0.2, 0.22))

	# Corner pillar for hiding behind
	_add_box(Vector3(fx - 1.5, height / 2.0, fz - 1.5), Vector3(1.0, height, 1.0), Color(0.4, 0.4, 0.42))

	# Target inside
	var dummy := Node3D.new()
	dummy.set_script(DummyScript)
	dummy.position = Vector3(fx + 1.0, 0.1, fz - 1.0)
	add_child(dummy)


# --- Grenade area ---

func _build_grenade_area() -> void:
	var grenade_range := Node3D.new()
	grenade_range.set_script(GrenadeRangeScript)
	grenade_range.position = Vector3(0, 0.1, -60.0)
	add_child(grenade_range)


# --- Weapon rack ---

func _build_weapon_rack() -> void:
	var rx := 0.0
	var rz := 3.0

	# Visual rack
	_add_box(Vector3(rx, 0.6, rz), Vector3(2.0, 1.2, 0.5), Color(0.4, 0.3, 0.2))

	_weapon_rack_label = Label3D.new()
	_weapon_rack_label.text = "WEAPON RACK [E]\nRefill ammo + grenades"
	_weapon_rack_label.position = Vector3(rx, 1.8, rz)
	_weapon_rack_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_weapon_rack_label.font_size = 28
	_weapon_rack_label.outline_size = 5
	_weapon_rack_label.modulate = Color(0.3, 1.0, 0.3)
	add_child(_weapon_rack_label)

	# Interaction area
	_rack_area = Area3D.new()
	_rack_area.collision_layer = 0
	_rack_area.collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.0, 2.0)
	col.shape = shape
	_rack_area.add_child(col)
	_rack_area.position = Vector3(rx, 1.0, rz)
	add_child(_rack_area)


# --- Section navigation labels ---

func _build_section_labels() -> void:
	_add_label(Vector3(0, 0.5, 1.0), "← PEN TEST     SPRAY WALL →", 20, Color(0.6, 0.6, 0.6))
	_add_label(Vector3(-12, 0.5, -14.0), "↓ FLASH ROOM", 20, Color(0.6, 0.6, 0.6))
	_add_label(Vector3(12, 0.5, -14.0), "↓ SMOKE CORRIDOR", 20, Color(0.6, 0.6, 0.6))
	_add_label(Vector3(0, 0.5, -55.0), "↓ GRENADE RANGE", 20, Color(0.6, 0.6, 0.6))


# --- Helpers ---

func _add_box(pos: Vector3, sz: Vector3, color: Color) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.use_collision = true
	box.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	box.position = pos
	add_child(box)
	return box


func _add_ground_strip(pos: Vector3, width: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.02, 0.05)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	mesh.position = pos
	add_child(mesh)


func _add_label(pos: Vector3, text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = size
	label.outline_size = max(size / 6, 3)
	label.modulate = color
	add_child(label)
	return label
