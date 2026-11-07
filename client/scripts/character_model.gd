class_name CharacterModel
extends Node3D

const MC = preload("res://shared/scripts/movement_constants.gd")

var skeleton: Skeleton3D = null
var mesh_instance: MeshInstance3D = null
var weapon_attach: BoneAttachment3D = null
var head_attach: BoneAttachment3D = null
var current_weapon_visual: Node3D = null
var _model_root: Node = null
var _team_color := Color.WHITE
var _is_fallback := false

const MODEL_PATHS := {
	"angels": "res://assets/characters/angel_templar/angel_templar.glb",
}


func setup(faction: String = "angels") -> void:
	var path: String = MODEL_PATHS.get(faction, MODEL_PATHS["angels"])
	_load_model(path)
	position.y = -MC.HULL_STANDING_HEIGHT * 0.5


func _load_model(path: String) -> void:
	if _model_root:
		_model_root.queue_free()
		_model_root = null
		skeleton = null
		mesh_instance = null
		weapon_attach = null
		head_attach = null

	var scene: PackedScene = load(path)
	if not scene:
		push_warning("CharacterModel: failed to load %s, using fallback" % path)
		_create_fallback()
		return

	_model_root = scene.instantiate()
	add_child(_model_root)
	_is_fallback = false

	skeleton = _find_typed(_model_root, &"Skeleton3D") as Skeleton3D
	mesh_instance = _find_typed(_model_root, &"MeshInstance3D") as MeshInstance3D

	if skeleton:
		_setup_bone_attachments()

	if _team_color != Color.WHITE:
		_apply_color(_team_color)


func _create_fallback() -> void:
	_is_fallback = true
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.750
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 0.85)
	capsule.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = capsule
	mi.position.y = 1.750 * 0.5
	add_child(mi)
	mesh_instance = mi
	_model_root = mi


func _setup_bone_attachments() -> void:
	var hand_r_idx := skeleton.find_bone("hand_r")
	if hand_r_idx >= 0:
		weapon_attach = BoneAttachment3D.new()
		weapon_attach.name = "WeaponAttach"
		weapon_attach.bone_name = "hand_r"
		skeleton.add_child(weapon_attach)

	var head_idx := skeleton.find_bone("head")
	if head_idx >= 0:
		head_attach = BoneAttachment3D.new()
		head_attach.name = "HeadAttach"
		head_attach.bone_name = "head"
		skeleton.add_child(head_attach)


func set_team_color(color: Color) -> void:
	_team_color = color
	_apply_color(color)


func _apply_color(color: Color) -> void:
	if not mesh_instance:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat


func set_weapon_model(_weapon_idx: int) -> void:
	if current_weapon_visual:
		current_weapon_visual.queue_free()
		current_weapon_visual = null

	if not weapon_attach:
		return

	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.08, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.25)
	box.material = mat
	var vis := MeshInstance3D.new()
	vis.mesh = box
	vis.name = "WeaponVisual"
	weapon_attach.add_child(vis)
	current_weapon_visual = vis


func set_ducked(ducked: bool) -> void:
	if ducked:
		var ratio: float = MC.HULL_DUCKING_HEIGHT / MC.HULL_STANDING_HEIGHT
		scale.y = ratio
		position.y = -MC.HULL_DUCKING_HEIGHT * 0.5
	else:
		scale.y = 1.0
		position.y = -MC.HULL_STANDING_HEIGHT * 0.5


func set_faction(faction: String) -> void:
	var path: String = MODEL_PATHS.get(faction, MODEL_PATHS["angels"])
	_load_model(path)
	if _team_color != Color.WHITE:
		_apply_color(_team_color)


static func _find_typed(root: Node, type_name: StringName) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_typed(child, type_name)
		if found:
			return found
	return null
