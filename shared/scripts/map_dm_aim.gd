extends Node3D

## MAP_DM_AIM — Deathmatch aim map based on aim_map BSP layout.
## BSP coordinates converted: BSP X → Godot X, BSP Y → Godot −Z, BSP Z → Godot Y.
## Scale: 1 GoldSrc unit = 1/39.37 m. Map centered at origin, floor at Y = 0.

const FLOOR_COLOR := Color(0.35, 0.35, 0.32)
const WALL_COLOR := Color(0.45, 0.42, 0.38)
const WALL_SIDE_COLOR := Color(0.42, 0.40, 0.36)
const PLAT_COLOR := Color(0.48, 0.45, 0.40)
const RAMP_COLOR := Color(0.50, 0.47, 0.42)
const STAIR_COLOR := Color(0.46, 0.43, 0.38)
const CRATE_COLOR := Color(0.60, 0.45, 0.25)
const LADDER_COLOR := Color(0.55, 0.50, 0.40)
const PORTAL_MARKER_COLOR := Color(0.3, 0.8, 0.5, 0.35)
const BUY_MARKER_COLOR := Color(0.3, 0.5, 0.8, 0.25)

const MAP_W := 38.3
const MAP_D := 70.0
const WALL_H := 8.0
const PLAT_TOP := 5.38
const PLAT_THICK := 0.5
const PLAT_W := 17.9

var spawn_points: Array[Vector3] = [
	Vector3(-6.0, 1.0, 31.0),
	Vector3(0.0, 1.0, 31.0),
	Vector3(6.0, 1.0, 31.0),
	Vector3(-6.0, 1.0, -31.0),
	Vector3(0.0, 1.0, -31.0),
	Vector3(6.0, 1.0, -31.0),
	Vector3(-5.0, 1.0, 0.0),
	Vector3(5.0, 1.0, 0.0),
]

var angels_spawns: Array[Vector3] = [
	Vector3(-6.0, 1.0, 31.0),
	Vector3(-3.0, 1.0, 31.0),
	Vector3(0.0, 1.0, 31.0),
	Vector3(3.0, 1.0, 31.0),
	Vector3(6.0, 1.0, 31.0),
]

var demons_spawns: Array[Vector3] = [
	Vector3(-6.0, 1.0, -31.0),
	Vector3(-3.0, 1.0, -31.0),
	Vector3(0.0, 1.0, -31.0),
	Vector3(3.0, 1.0, -31.0),
	Vector3(6.0, 1.0, -31.0),
]

var portal_sites: Dictionary = {
	&"A": Vector3(1.0, 5.9, 25.3),
	&"B": Vector3(-0.8, 5.9, -25.3),
}


func _ready() -> void:
	_build_arena()
	_build_angels_side()
	_build_demons_side()
	_build_zones()
	_build_lighting()


# ---------------------------------------------------------------------------
# Arena shell
# ---------------------------------------------------------------------------

func _build_arena() -> void:
	_add_box("Floor", Vector3(0, -0.1, 0), Vector3(MAP_W, 0.2, MAP_D), FLOOR_COLOR)
	var hw := MAP_W * 0.5
	var hd := MAP_D * 0.5
	_add_box("WallN", Vector3(0, WALL_H * 0.5, -hd), Vector3(MAP_W, WALL_H, 0.5), WALL_COLOR)
	_add_box("WallS", Vector3(0, WALL_H * 0.5, hd), Vector3(MAP_W, WALL_H, 0.5), WALL_COLOR)
	_add_box("WallW", Vector3(-hw, WALL_H * 0.5, 0), Vector3(0.5, WALL_H, MAP_D), WALL_SIDE_COLOR)
	_add_box("WallE", Vector3(hw, WALL_H * 0.5, 0), Vector3(0.5, WALL_H, MAP_D), WALL_SIDE_COLOR)


# ---------------------------------------------------------------------------
# Angels side (+Z) — CT spawns, platform, cover
# ---------------------------------------------------------------------------

func _build_angels_side() -> void:
	var pcx := 1.0
	var front_z := 21.5
	var back_z := 29.15
	var depth := back_z - front_z
	var center_z := (front_z + back_z) * 0.5
	var deck_y := PLAT_TOP - PLAT_THICK * 0.5

	# Platform deck
	_add_box("PlatAngels", Vector3(pcx, deck_y, center_z),
			Vector3(PLAT_W, PLAT_THICK, depth), PLAT_COLOR)

	# Support columns (BSP models 1 & 2, extended floor-to-deck)
	var col_h := PLAT_TOP - PLAT_THICK
	_add_box("SupportAngelsL", Vector3(-7.1, col_h * 0.5, 22.2),
			Vector3(1.63, col_h, 1.63), PLAT_COLOR)
	_add_box("SupportAngelsR", Vector3(9.1, col_h * 0.5, 22.2),
			Vector3(1.63, col_h, 1.63), PLAT_COLOR)

	# East ramp — front of platform, descending toward arena
	var ramp_x := pcx + PLAT_W * 0.5 + 1.3
	_add_ramp("RampE_Angels", Vector3(ramp_x, 0, front_z - 3.5),
			PLAT_TOP, 2.5, 7.0, true, RAMP_COLOR)
	_add_box("LandingE_Angels", Vector3(ramp_x, deck_y, front_z + 0.5),
			Vector3(2.5, PLAT_THICK, 1.5), PLAT_COLOR)

	# West staircase — front of platform, descending toward arena
	var stair_x := pcx - PLAT_W * 0.5 - 1.3
	_add_stairs("StairW_Angels", Vector3(stair_x, 0, front_z - 7.5),
			Vector3(0, 0, 7.5), PLAT_TOP, 2.5, 12, STAIR_COLOR)
	_add_box("LandingW_Angels", Vector3(stair_x, deck_y, front_z + 0.5),
			Vector3(2.5, PLAT_THICK, 1.5), PLAT_COLOR)

	# Front ladder (faces toward mid-map)
	_add_ladder("LadderAngels", Vector3(pcx, 0, front_z - 0.15),
			PLAT_TOP, 1.0, LADDER_COLOR, Vector3.FORWARD)

	# Mid-arena cover crates (BSP models 3-9)
	_add_box("CrateTallL_A", Vector3(-8.3, 1.65, 12.0), Vector3(1.63, 3.30, 1.63), CRATE_COLOR)
	_add_box("CrateMedL_A", Vector3(-6.7, 0.88, 12.9), Vector3(1.60, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateStep_A", Vector3(-5.5, 0.46, 13.5), Vector3(0.79, 0.91, 0.81), CRATE_COLOR)
	_add_box("CrateMedC_A", Vector3(-5.0, 0.88, 11.9), Vector3(1.60, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateTallC_A", Vector3(-3.3, 1.65, 11.0), Vector3(1.63, 3.30, 1.63), CRATE_COLOR)
	_add_box("CrateLargeR_A", Vector3(2.0, 1.13, 12.0), Vector3(2.29, 2.26, 1.93), CRATE_COLOR)
	_add_box("CrateMedR_A", Vector3(3.9, 0.81, 12.9), Vector3(1.63, 1.63, 1.63), CRATE_COLOR)

	# Cover crates at east ramp base
	_add_box("CrateMedRamp_A", Vector3(12.5, 0.88, 13.5), Vector3(1.63, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateSmRamp_A", Vector3(10.0, 0.46, 13.0), Vector3(0.79, 0.91, 0.81), CRATE_COLOR)


# ---------------------------------------------------------------------------
# Demons side (−Z) — T spawns, platform, cover
# ---------------------------------------------------------------------------

func _build_demons_side() -> void:
	var pcx := -0.8
	var front_z := -21.5
	var back_z := -29.15
	var depth := absf(back_z - front_z)
	var center_z := (front_z + back_z) * 0.5
	var deck_y := PLAT_TOP - PLAT_THICK * 0.5

	# Platform deck
	_add_box("PlatDemons", Vector3(pcx, deck_y, center_z),
			Vector3(PLAT_W, PLAT_THICK, depth), PLAT_COLOR)

	# Support columns (BSP models 17 & 18)
	var col_h := PLAT_TOP - PLAT_THICK
	_add_box("SupportDemonsL", Vector3(-8.9, col_h * 0.5, -22.2),
			Vector3(1.63, col_h, 1.63), PLAT_COLOR)
	_add_box("SupportDemonsR", Vector3(7.3, col_h * 0.5, -22.2),
			Vector3(1.63, col_h, 1.63), PLAT_COLOR)

	# West ramp — front of platform, descending toward arena
	var ramp_x := pcx - PLAT_W * 0.5 - 1.3
	_add_ramp("RampW_Demons", Vector3(ramp_x, 0, front_z + 3.5),
			PLAT_TOP, 2.5, 7.0, false, RAMP_COLOR)
	_add_box("LandingW_Demons", Vector3(ramp_x, deck_y, front_z - 0.5),
			Vector3(2.5, PLAT_THICK, 1.5), PLAT_COLOR)

	# East staircase — front of platform, descending toward arena
	var stair_x := pcx + PLAT_W * 0.5 + 1.3
	_add_stairs("StairE_Demons", Vector3(stair_x, 0, front_z + 7.5),
			Vector3(0, 0, -7.5), PLAT_TOP, 2.5, 12, STAIR_COLOR)
	_add_box("LandingE_Demons", Vector3(stair_x, deck_y, front_z - 0.5),
			Vector3(2.5, PLAT_THICK, 1.5), PLAT_COLOR)

	# Front ladder (faces toward mid-map)
	_add_ladder("LadderDemons", Vector3(pcx, 0, front_z + 0.15),
			PLAT_TOP, 1.0, LADDER_COLOR, Vector3.BACK)

	# Mid-arena cover crates (BSP models 10-16)
	_add_box("CrateTallL_D", Vector3(3.5, 1.65, -10.9), Vector3(1.63, 3.30, 1.63), CRATE_COLOR)
	_add_box("CrateMedL_D", Vector3(5.2, 0.88, -11.9), Vector3(1.60, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateStep_D", Vector3(5.7, 0.46, -13.5), Vector3(0.79, 0.91, 0.81), CRATE_COLOR)
	_add_box("CrateMedC_D", Vector3(6.9, 0.88, -12.9), Vector3(1.60, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateTallC_D", Vector3(8.5, 1.65, -12.0), Vector3(1.63, 3.30, 1.63), CRATE_COLOR)
	_add_box("CrateLargeR_D", Vector3(-1.8, 1.13, -11.9), Vector3(2.29, 2.26, 1.93), CRATE_COLOR)
	_add_box("CrateMedR_D", Vector3(-3.7, 0.81, -12.8), Vector3(1.63, 1.63, 1.63), CRATE_COLOR)

	# Cover crates at west ramp base
	_add_box("CrateMedRamp_D", Vector3(-12.3, 0.88, -13.5), Vector3(1.63, 1.75, 1.63), CRATE_COLOR)
	_add_box("CrateSmRamp_D", Vector3(-9.8, 0.46, -13.0), Vector3(0.79, 0.91, 0.81), CRATE_COLOR)


# ---------------------------------------------------------------------------
# Gameplay zones
# ---------------------------------------------------------------------------

func _build_zones() -> void:
	for site_name: StringName in portal_sites:
		var pos: Vector3 = portal_sites[site_name]
		_add_zone("PortalSite_" + site_name, pos,
				Vector3(4.0, 2.0, 4.0), "portal_site", PORTAL_MARKER_COLOR)

	_add_zone("BuyZoneAngels", Vector3(0, 2.0, 32.0),
			Vector3(16.0, 4.0, 5.0), "buy_zone", BUY_MARKER_COLOR)
	_add_zone("BuyZoneDemons", Vector3(0, 2.0, -32.0),
			Vector3(16.0, 4.0, 5.0), "buy_zone", BUY_MARKER_COLOR)


# ---------------------------------------------------------------------------
# Lighting
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

func _add_box(node_name: String, pos: Vector3, box_size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box_size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	body.add_child(mesh_inst)

	add_child(body)


func _add_ramp(node_name: String, base_pos: Vector3, height: float,
		width: float, depth: float, flip: bool, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = base_pos

	var hw := width * 0.5
	var hd := depth * 0.5
	var pts := PackedVector3Array()
	if flip:
		pts.append(Vector3(-hw, 0, -hd))
		pts.append(Vector3( hw, 0, -hd))
		pts.append(Vector3(-hw, 0,  hd))
		pts.append(Vector3( hw, 0,  hd))
		pts.append(Vector3(-hw, height,  hd))
		pts.append(Vector3( hw, height,  hd))
	else:
		pts.append(Vector3(-hw, 0, -hd))
		pts.append(Vector3( hw, 0, -hd))
		pts.append(Vector3(-hw, 0,  hd))
		pts.append(Vector3( hw, 0,  hd))
		pts.append(Vector3(-hw, height, -hd))
		pts.append(Vector3( hw, height, -hd))
	var col := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	col.shape = shape
	body.add_child(col)

	# Visual mesh: smooth tilted slab
	var angle := atan2(height, depth)
	if flip:
		angle = -angle
	var hyp := depth / cos(absf(angle))
	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(width, 0.15, hyp)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	mesh_inst.position.y = height * 0.5
	mesh_inst.rotation.x = angle
	body.add_child(mesh_inst)

	add_child(body)


func _add_stairs(base_name: String, start_pos: Vector3, direction: Vector3,
		total_height: float, width: float, step_count: int, color: Color) -> void:
	var step_h := total_height / step_count
	var step_offset := direction / step_count
	var step_depth := step_offset.length()
	for i in range(step_count):
		var h := step_h * (i + 1)
		var pos := start_pos + step_offset * (float(i) + 0.5)
		pos.y = h * 0.5
		_add_box("%s_%02d" % [base_name, i], pos, Vector3(width, h, step_depth), color)


func _add_ladder(base_name: String, pos: Vector3, height: float,
		width: float, color: Color, face_dir: Vector3 = Vector3.FORWARD) -> void:
	var fd := face_dir.normalized()

	# Solid wall behind the ladder (shorter at top to allow ledge dismount)
	var wall_h := height - 1.0
	var wall_pos := Vector3(pos.x - fd.x * 0.2, wall_h * 0.5, pos.z - fd.z * 0.2)
	_add_box(base_name + "_Wall", wall_pos,
			Vector3(width + 0.4, wall_h, 0.3), color)

	# Visual rungs (no collision — wall handles it)
	var rung_spacing := 0.45
	var rung_count := int(height / rung_spacing)
	for i in range(rung_count):
		var rung_y := rung_spacing * (i + 1)
		if rung_y > height:
			break
		var mi := MeshInstance3D.new()
		mi.name = "%s_Rung%02d" % [base_name, i]
		var bm := BoxMesh.new()
		bm.size = Vector3(width, 0.08, 0.15)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(0.2)
		bm.material = mat
		mi.mesh = bm
		mi.position = Vector3(pos.x, rung_y, pos.z)
		add_child(mi)

	# Climbing trigger — extends above platform so player can vault onto deck
	var area := LadderVolume.new()
	area.name = base_name + "_Zone"
	area.face_normal = fd
	var zone_h := height + 1.5
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 0.4, zone_h, 1.0)
	col.shape = shape
	area.add_child(col)
	area.position = Vector3(pos.x + fd.x * 0.2, zone_h * 0.5, pos.z + fd.z * 0.2)
	area.add_to_group("ladder")
	add_child(area)


func _add_zone(zone_name: String, pos: Vector3, zone_size: Vector3,
		group_name: String, color: Color) -> void:
	var area := Area3D.new()
	area.name = zone_name
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = zone_size
	col.shape = shape
	area.add_child(col)
	area.position = pos
	area.add_to_group(group_name)

	var mesh_inst := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = zone_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	area.add_child(mesh_inst)

	add_child(area)
