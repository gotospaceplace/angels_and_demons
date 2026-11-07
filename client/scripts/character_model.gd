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

var anim_tree: AnimationTree = null
var _skel_path: String = ""
var _duck_blend: float = 0.0
var _target_duck: float = 0.0

const MODEL_PATHS := {
	"angels": "res://assets/characters/angel_templar/angel_templar.glb",
}

const WALK_CYCLE_TIME := 0.8
const IDLE_CYCLE_TIME := 2.0


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
	if anim_tree:
		anim_tree.queue_free()
		anim_tree = null

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
		_setup_animations()

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


# --- Animation system ---


func _setup_animations() -> void:
	if not skeleton or _is_fallback:
		return
	_skel_path = str(get_path_to(skeleton))

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	add_child(anim_tree)

	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _create_idle_anim())
	lib.add_animation(&"walk", _create_walk_anim())
	lib.add_animation(&"crouch_idle", _create_crouch_idle_anim())
	lib.add_animation(&"crouch_walk", _create_crouch_walk_anim())
	anim_tree.add_animation_library(&"", lib)

	anim_tree.tree_root = _build_blend_tree()
	anim_tree.active = true


func _build_blend_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()

	var idle_n := AnimationNodeAnimation.new()
	idle_n.animation = &"idle"
	tree.add_node(&"idle", idle_n)

	var walk_n := AnimationNodeAnimation.new()
	walk_n.animation = &"walk"
	tree.add_node(&"walk", walk_n)

	var stand_blend := AnimationNodeBlend2.new()
	tree.add_node(&"stand_blend", stand_blend)
	tree.connect_node(&"stand_blend", 0, &"idle")
	tree.connect_node(&"stand_blend", 1, &"walk")

	var ci_n := AnimationNodeAnimation.new()
	ci_n.animation = &"crouch_idle"
	tree.add_node(&"crouch_idle", ci_n)

	var cw_n := AnimationNodeAnimation.new()
	cw_n.animation = &"crouch_walk"
	tree.add_node(&"crouch_walk", cw_n)

	var crouch_speed := AnimationNodeBlend2.new()
	tree.add_node(&"crouch_speed", crouch_speed)
	tree.connect_node(&"crouch_speed", 0, &"crouch_idle")
	tree.connect_node(&"crouch_speed", 1, &"crouch_walk")

	var duck_blend := AnimationNodeBlend2.new()
	tree.add_node(&"duck_blend", duck_blend)
	tree.connect_node(&"duck_blend", 0, &"stand_blend")
	tree.connect_node(&"duck_blend", 1, &"crouch_speed")

	tree.connect_node(&"output", 0, &"duck_blend")

	return tree


func _bone_rot(anim: Animation, bone: String, times: Array, quats: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, NodePath(_skel_path + ":" + bone))
	for i in range(times.size()):
		anim.rotation_track_insert_key(idx, times[i], quats[i])


func _create_idle_anim() -> Animation:
	var anim := Animation.new()
	anim.length = IDLE_CYCLE_TIME
	anim.loop_mode = Animation.LOOP_LINEAR
	var I := Quaternion.IDENTITY
	var up := _rot_x(-1.0)
	var dn := _rot_x(1.0)
	_bone_rot(anim, "spine_01", [0.0, 0.5, 1.0, 1.5, 2.0], [I, up, I, dn, I])
	return anim


func _create_walk_anim() -> Animation:
	var anim := Animation.new()
	anim.length = WALK_CYCLE_TIME
	anim.loop_mode = Animation.LOOP_LINEAR
	var I := Quaternion.IDENTITY
	var tf := _rot_x(-20.0)
	var tb := _rot_x(20.0)
	var kb := _rot_x(35.0)
	var ke := _rot_x(5.0)
	var af := _rot_x(-12.0)
	var ab := _rot_x(12.0)
	var pl := _rot_y(-3.0)
	var pr := _rot_y(3.0)
	var t := [0.0, 0.2, 0.4, 0.6, 0.8]
	_bone_rot(anim, "thigh_r", t, [tf, I, tb, I, tf])
	_bone_rot(anim, "shin_r", t, [ke, kb, ke, I, ke])
	_bone_rot(anim, "thigh_l", t, [tb, I, tf, I, tb])
	_bone_rot(anim, "shin_l", t, [ke, I, ke, kb, ke])
	_bone_rot(anim, "upper_arm_r", t, [ab, I, af, I, ab])
	_bone_rot(anim, "upper_arm_l", t, [af, I, ab, I, af])
	_bone_rot(anim, "pelvis", t, [pl, I, pr, I, pl])
	_bone_rot(anim, "spine_01", t, [pr, I, pl, I, pr])
	return anim


func _create_crouch_idle_anim() -> Animation:
	var anim := Animation.new()
	anim.length = IDLE_CYCLE_TIME
	anim.loop_mode = Animation.LOOP_LINEAR
	var ct := _rot_x(-45.0)
	var ck := _rot_x(70.0)
	var cs := _rot_x(-15.0)
	var breath := ct * _rot_x(-1.0)
	var cs_up := cs * _rot_x(-1.0)
	var cs_dn := cs * _rot_x(1.0)
	_bone_rot(anim, "thigh_l", [0.0, 1.0, 2.0], [ct, breath, ct])
	_bone_rot(anim, "thigh_r", [0.0, 1.0, 2.0], [ct, breath, ct])
	_bone_rot(anim, "shin_l", [0.0, 2.0], [ck, ck])
	_bone_rot(anim, "shin_r", [0.0, 2.0], [ck, ck])
	_bone_rot(anim, "spine_01", [0.0, 0.5, 1.0, 1.5, 2.0], [cs, cs_up, cs, cs_dn, cs])
	return anim


func _create_crouch_walk_anim() -> Animation:
	var anim := Animation.new()
	anim.length = WALK_CYCLE_TIME
	anim.loop_mode = Animation.LOOP_LINEAR
	var ct := _rot_x(-45.0)
	var ck := _rot_x(70.0)
	var cs := _rot_x(-15.0)
	var sw := 10.0
	var I := Quaternion.IDENTITY
	var t := [0.0, 0.2, 0.4, 0.6, 0.8]
	_bone_rot(anim, "thigh_r", t, [
		ct * _rot_x(-sw), ct, ct * _rot_x(sw), ct, ct * _rot_x(-sw)])
	_bone_rot(anim, "shin_r", t, [
		ck * _rot_x(-5.0), ck * _rot_x(15.0), ck * _rot_x(-5.0), ck, ck * _rot_x(-5.0)])
	_bone_rot(anim, "thigh_l", t, [
		ct * _rot_x(sw), ct, ct * _rot_x(-sw), ct, ct * _rot_x(sw)])
	_bone_rot(anim, "shin_l", t, [
		ck * _rot_x(-5.0), ck, ck * _rot_x(-5.0), ck * _rot_x(15.0), ck * _rot_x(-5.0)])
	_bone_rot(anim, "upper_arm_r", t, [
		_rot_x(8.0), I, _rot_x(-8.0), I, _rot_x(8.0)])
	_bone_rot(anim, "upper_arm_l", t, [
		_rot_x(-8.0), I, _rot_x(8.0), I, _rot_x(-8.0)])
	_bone_rot(anim, "spine_01", t, [cs, cs, cs, cs, cs])
	return anim


static func _rot_x(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(deg))


static func _rot_y(deg: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(deg))


# --- Movement ---


func update_movement(local_velocity: Vector3, _on_ground: bool) -> void:
	if not anim_tree or not anim_tree.active:
		return
	var horiz_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var speed_norm := clampf(horiz_speed / MC.GROUND_SPEED_CLAMP, 0.0, 1.0)
	anim_tree.set(&"parameters/stand_blend/blend_amount", speed_norm)
	anim_tree.set(&"parameters/crouch_speed/blend_amount", speed_norm)


func _process(delta: float) -> void:
	if not anim_tree or not anim_tree.active:
		return
	_duck_blend = move_toward(_duck_blend, _target_duck, delta / MC.DUCK_TIME)
	position.y = lerpf(-MC.HULL_STANDING_HEIGHT * 0.5, -MC.HULL_DUCKING_HEIGHT * 0.5, _duck_blend)
	anim_tree.set(&"parameters/duck_blend/blend_amount", _duck_blend)


# --- Team color ---


func set_team_color(color: Color) -> void:
	_team_color = color
	_apply_color(color)


func _apply_color(color: Color) -> void:
	if not mesh_instance:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat


# --- Weapons ---


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


# --- Ducking ---


func set_ducked(ducked: bool) -> void:
	_target_duck = 1.0 if ducked else 0.0
	if not anim_tree:
		if ducked:
			scale.y = MC.HULL_DUCKING_HEIGHT / MC.HULL_STANDING_HEIGHT
			position.y = -MC.HULL_DUCKING_HEIGHT * 0.5
		else:
			scale.y = 1.0
			position.y = -MC.HULL_STANDING_HEIGHT * 0.5


# --- Faction ---


func set_faction(faction: String) -> void:
	var path: String = MODEL_PATHS.get(faction, MODEL_PATHS["angels"])
	_load_model(path)
	if _team_color != Color.WHITE:
		_apply_color(_team_color)


# --- Utility ---


static func _find_typed(root: Node, type_name: StringName) -> Node:
	if root.is_class(type_name):
		return root
	for child in root.get_children():
		var found := _find_typed(child, type_name)
		if found:
			return found
	return null
