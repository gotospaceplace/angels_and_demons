class_name Viewmodel
extends Node3D

const RENDER_LAYER := 2
const VIEWMODEL_FOV := 54.0

const FP_ARMS_PATHS := {
	"angels": "res://assets/characters/angel_templar/angel_templar_fp.glb",
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

var _arms_root: Node = null
var _arms_skeleton: Skeleton3D = null
var _arms_mesh: MeshInstance3D = null
var _weapon_visual: Node3D = null
var _weapon_attach: BoneAttachment3D = null
var _current_weapon_idx: int = -1
var _faction: String = "angels"


func setup(faction: String = "angels") -> void:
	_faction = faction
	_load_arms()
	set_weapon(2)


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
	position = WEAPON_OFFSETS.get(weapon_idx, DEFAULT_OFFSET)

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
