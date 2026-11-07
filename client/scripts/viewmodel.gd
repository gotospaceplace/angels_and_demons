class_name Viewmodel
extends Node3D

const RENDER_LAYER := 2
const VIEWMODEL_FOV := 54.0

const FP_ARMS_PATHS := {
	"angels": "res://assets/characters/angel_templar/angel_templar_fp.glb",
	"demons": "res://assets/characters/d1_brute/d1_brute_fp.glb",
}

const WEAPON_MODEL_PATHS := {
	0: "res://assets/weapons/melee/melee_world.glb",
	1: "res://assets/weapons/usp/usp_world.glb",
	2: "res://assets/weapons/ak47/ak47_world.glb",
	3: "res://assets/weapons/m4a1/m4a1_world.glb",
	4: "res://assets/weapons/awp/awp_world.glb",
}

const WEAPON_OFFSETS := {
	0: Vector3(0.05, -0.12, -0.22),
	1: Vector3(0.08, -0.14, -0.28),
	2: Vector3(0.10, -0.15, -0.35),
	3: Vector3(0.10, -0.15, -0.35),
	4: Vector3(0.10, -0.16, -0.40),
}

const DEFAULT_OFFSET := Vector3(0.10, -0.15, -0.35)

# Animation state enum
enum AnimState { IDLE, FIRE, RELOAD, EQUIP }

# Fire kick: z-position pullback (meters), pitch rotation (degrees)
const FIRE_KICK := {
	0: Vector2(0.03, 8.0),
	1: Vector2(0.02, 3.0),
	2: Vector2(0.03, 2.5),
	3: Vector2(0.025, 2.0),
	4: Vector2(0.06, 5.0),
}
const DEFAULT_KICK := Vector2(0.03, 3.0)

# Fire animation duration per weapon (seconds)
const FIRE_ANIM_DURATIONS := {
	0: 0.30,
	1: 0.12,
	2: 0.08,
	3: 0.07,
	4: 0.40,
}
const DEFAULT_FIRE_DURATION := 0.15

# Idle bob parameters
const IDLE_BOB_SPEED := 1.5
const IDLE_BOB_X := 0.002
const IDLE_BOB_Y := 0.003

# Walk bob parameters
const WALK_BOB_SPEED := 10.0
const WALK_BOB_X := 0.006
const WALK_BOB_Y := 0.008

# Equip: start this far below and raise up
const EQUIP_DROP := 0.15

# Reload: lower by this amount
const RELOAD_DROP := 0.08
const RELOAD_TILT := 15.0

var _arms_root: Node = null
var _arms_skeleton: Skeleton3D = null
var _arms_mesh: MeshInstance3D = null
var _weapon_visual: Node3D = null
var _weapon_attach: BoneAttachment3D = null
var _current_weapon_idx: int = -1
var _faction: String = "angels"

# Animation state
var _anim_state: int = AnimState.IDLE
var _anim_time: float = 0.0
var _anim_duration: float = 0.0
var _bob_time: float = 0.0
var _base_position: Vector3 = Vector3.ZERO
var _player: CharacterBody3D = null


func setup(faction: String = "angels") -> void:
	_faction = faction
	_load_arms()
	set_weapon(2)


func _process(delta: float) -> void:
	if not visible:
		return
	_resolve_player()
	var speed := _get_player_speed()
	_bob_time += delta
	var anim_offset := Vector3.ZERO
	var anim_rotation := Vector3.ZERO

	match _anim_state:
		AnimState.IDLE:
			var bob := _calc_bob(speed, delta)
			anim_offset = bob

		AnimState.FIRE:
			_anim_time += delta
			var t := clampf(_anim_time / _anim_duration, 0.0, 1.0)
			var kick: Vector2 = FIRE_KICK.get(_current_weapon_idx, DEFAULT_KICK)
			# Sharp attack, smooth decay
			var intensity: float
			if t < 0.2:
				intensity = t / 0.2
			else:
				intensity = 1.0 - (t - 0.2) / 0.8
			anim_offset.z = kick.x * intensity
			anim_rotation.x = deg_to_rad(kick.y) * intensity
			anim_offset += _calc_bob(speed, delta) * (1.0 - intensity * 0.5)
			if t >= 1.0:
				_anim_state = AnimState.IDLE

		AnimState.RELOAD:
			_anim_time += delta
			var t := clampf(_anim_time / _anim_duration, 0.0, 1.0)
			# Down in first 15%, hold 70%, up in last 15%
			var drop_intensity: float
			if t < 0.15:
				drop_intensity = t / 0.15
			elif t < 0.85:
				drop_intensity = 1.0
			else:
				drop_intensity = 1.0 - (t - 0.85) / 0.15
			anim_offset.y = -RELOAD_DROP * drop_intensity
			anim_rotation.z = deg_to_rad(RELOAD_TILT) * drop_intensity
			if t >= 1.0:
				_anim_state = AnimState.IDLE

		AnimState.EQUIP:
			_anim_time += delta
			var t := clampf(_anim_time / _anim_duration, 0.0, 1.0)
			# Smooth raise: cubic ease-out
			var raise_t := 1.0 - pow(1.0 - t, 3.0)
			anim_offset.y = -EQUIP_DROP * (1.0 - raise_t)
			if t >= 1.0:
				_anim_state = AnimState.IDLE

	position = _base_position + anim_offset
	rotation = anim_rotation


func play_fire() -> void:
	_anim_state = AnimState.FIRE
	_anim_time = 0.0
	_anim_duration = FIRE_ANIM_DURATIONS.get(_current_weapon_idx, DEFAULT_FIRE_DURATION)


func play_reload(duration: float) -> void:
	_anim_state = AnimState.RELOAD
	_anim_time = 0.0
	_anim_duration = duration


func play_equip(duration: float) -> void:
	_anim_state = AnimState.EQUIP
	_anim_time = 0.0
	_anim_duration = duration


func get_anim_state() -> int:
	return _anim_state


func _calc_bob(speed: float, _delta: float) -> Vector3:
	var offset := Vector3.ZERO
	if speed > 0.5:
		offset.x = sin(_bob_time * WALK_BOB_SPEED) * WALK_BOB_X
		offset.y = -absf(cos(_bob_time * WALK_BOB_SPEED)) * WALK_BOB_Y
	else:
		offset.x = sin(_bob_time * IDLE_BOB_SPEED) * IDLE_BOB_X
		offset.y = sin(_bob_time * IDLE_BOB_SPEED * 0.7) * IDLE_BOB_Y
	return offset


func _resolve_player() -> void:
	if _player:
		return
	# Viewmodel → Camera3D → Head → Player
	var cam := get_parent()
	if cam:
		var head := cam.get_parent()
		if head:
			var p := head.get_parent()
			if p is CharacterBody3D:
				_player = p


func _get_player_speed() -> float:
	if not _player:
		return 0.0
	var h := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	return h.length()


func _load_arms() -> void:
	if _arms_root:
		_arms_root.queue_free()
		_arms_root = null
		_arms_skeleton = null
		_arms_mesh = null
		_weapon_attach = null

	var path: String = FP_ARMS_PATHS.get(_faction, FP_ARMS_PATHS["angels"])
	var scene: PackedScene = load(path)
	if not scene:
		push_warning("Viewmodel: failed to load FP arms %s" % path)
		return

	_arms_root = scene.instantiate()
	add_child(_arms_root)

	_arms_skeleton = _find_typed(_arms_root, &"Skeleton3D") as Skeleton3D
	_arms_mesh = _find_typed(_arms_root, &"MeshInstance3D") as MeshInstance3D

	if _arms_mesh:
		_arms_mesh.layers = 1 << (RENDER_LAYER - 1)

	if _arms_skeleton:
		var hand_r_idx := _arms_skeleton.find_bone("hand_r")
		if hand_r_idx >= 0:
			_weapon_attach = BoneAttachment3D.new()
			_weapon_attach.name = "WeaponAttach"
			_weapon_attach.bone_name = "hand_r"
			_arms_skeleton.add_child(_weapon_attach)


func set_weapon(weapon_idx: int) -> void:
	if _weapon_visual:
		_weapon_visual.queue_free()
		_weapon_visual = null

	_current_weapon_idx = weapon_idx
	_base_position = WEAPON_OFFSETS.get(weapon_idx, DEFAULT_OFFSET)
	position = _base_position

	var path: String = WEAPON_MODEL_PATHS.get(weapon_idx, "")
	var parent_node: Node3D = _weapon_attach if _weapon_attach else self

	if path != "":
		var scene: PackedScene = load(path)
		if scene:
			_weapon_visual = scene.instantiate()
			_weapon_visual.name = "ViewmodelWeapon"
			_set_render_layer_recursive(_weapon_visual, RENDER_LAYER)
			parent_node.add_child(_weapon_visual)
			return

	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, 0.20)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.3)
	box.material = mat
	var vis := MeshInstance3D.new()
	vis.mesh = box
	vis.name = "ViewmodelWeapon"
	vis.layers = 1 << (RENDER_LAYER - 1)
	parent_node.add_child(vis)
	_weapon_visual = vis


func set_visible_viewmodel(vis: bool) -> void:
	visible = vis


func get_current_weapon_idx() -> int:
	return _current_weapon_idx


func _set_render_layer_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (layer - 1)
	for child in node.get_children():
		_set_render_layer_recursive(child, layer)


static func _find_typed(root: Node, type_name: StringName) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_typed(child, type_name)
		if found:
			return found
	return null
