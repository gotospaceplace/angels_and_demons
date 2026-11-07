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
var _weapon_hold_node: AnimationNodeAnimation = null
var _weapon_action_node: AnimationNodeAnimation = null
var _current_weapon_idx: int = -1
var _prev_ammo: int = -1
var _is_dead := false

const DEATH_DURATION := 0.8

const MODEL_PATHS := {
	"angels": "res://assets/characters/angel_templar/angel_templar.glb",
	"demons": "res://assets/characters/d1_brute/d1_brute.glb",
}

const WALK_CYCLE_TIME := 0.8
const IDLE_CYCLE_TIME := 2.0

const UPPER_BODY_BONES := [
	"spine_01", "spine_02", "chest", "neck", "head",
	"clavicle_l", "upper_arm_l", "forearm_l", "hand_l",
	"clavicle_r", "upper_arm_r", "forearm_r", "hand_r",
]

const WEAPON_CATEGORY := {0: "melee", 1: "pistol", 2: "rifle", 3: "rifle", 4: "rifle"}
const HOLD_ANIM_MAP := {"melee": &"melee_hold", "pistol": &"pistol_hold", "rifle": &"rifle_hold"}
const FIRE_ANIM_MAP := {"melee": &"melee_slash", "pistol": &"pistol_fire", "rifle": &"rifle_fire"}

const WEAPON_MODEL_PATHS := {
	0: "res://assets/weapons/melee/melee_world.glb",
	1: "res://assets/weapons/usp/usp_world.glb",
	2: "res://assets/weapons/ak47/ak47_world.glb",
	3: "res://assets/weapons/m4a1/m4a1_world.glb",
	4: "res://assets/weapons/awp/awp_world.glb",
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
	if anim_tree:
		anim_tree.queue_free()
		anim_tree = null
		_weapon_hold_node = null
		_weapon_action_node = null

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
	lib.add_animation(&"rifle_hold", _create_hold_anim(_rifle_hold_pose()))
	lib.add_animation(&"rifle_fire", _create_fire_anim(_rifle_hold_pose(), 8.0))
	lib.add_animation(&"pistol_hold", _create_hold_anim(_pistol_hold_pose()))
	lib.add_animation(&"pistol_fire", _create_fire_anim(_pistol_hold_pose(), 6.0))
	lib.add_animation(&"melee_hold", _create_hold_anim(_melee_hold_pose()))
	lib.add_animation(&"melee_slash", _create_melee_slash_anim())
	lib.add_animation(&"weapon_switch", _create_switch_anim())
	anim_tree.add_animation_library(&"", lib)

	var tree := _build_blend_tree()
	anim_tree.tree_root = tree
	_weapon_hold_node = tree.get_node(&"weapon_hold") as AnimationNodeAnimation
	_weapon_action_node = tree.get_node(&"weapon_action") as AnimationNodeAnimation
	anim_tree.active = true
	anim_tree.set(&"parameters/weapon_layer/blend_amount", 1.0)


func _build_blend_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()

	# --- Locomotion layer ---
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

	# --- Weapon overlay layer ---
	var wh_n := AnimationNodeAnimation.new()
	wh_n.animation = &"rifle_hold"
	tree.add_node(&"weapon_hold", wh_n)

	var wa_n := AnimationNodeAnimation.new()
	wa_n.animation = &"rifle_fire"
	tree.add_node(&"weapon_action", wa_n)

	var weapon_os := AnimationNodeOneShot.new()
	weapon_os.fadein_time = 0.02
	weapon_os.fadeout_time = 0.08
	tree.add_node(&"weapon_oneshot", weapon_os)
	tree.connect_node(&"weapon_oneshot", 0, &"weapon_hold")
	tree.connect_node(&"weapon_oneshot", 1, &"weapon_action")

	var weapon_layer := AnimationNodeBlend2.new()
	weapon_layer.filter_enabled = true
	for bone_name in UPPER_BODY_BONES:
		weapon_layer.set_filter_path(NodePath(_skel_path + ":" + bone_name), true)
	tree.add_node(&"weapon_layer", weapon_layer)
	tree.connect_node(&"weapon_layer", 0, &"duck_blend")
	tree.connect_node(&"weapon_layer", 1, &"weapon_oneshot")

	tree.connect_node(&"output", 0, &"weapon_layer")

	return tree


# --- Animation track helper ---


func _bone_rot(anim: Animation, bone: String, times: Array, quats: Array) -> void:
	var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
	anim.track_set_path(idx, NodePath(_skel_path + ":" + bone))
	for i in range(times.size()):
		anim.rotation_track_insert_key(idx, times[i], quats[i])


# --- Locomotion animations ---


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


# --- Combat animations ---


func _rifle_hold_pose() -> Dictionary:
	return {
		"upper_arm_r": _rot_x(-80.0) * _rot_z(5.0),
		"forearm_r": _rot_x(-45.0),
		"upper_arm_l": _rot_x(-75.0) * _rot_z(-5.0),
		"forearm_l": _rot_x(-50.0),
		"chest": _rot_x(-5.0),
	}


func _pistol_hold_pose() -> Dictionary:
	return {
		"upper_arm_r": _rot_x(-85.0),
		"forearm_r": _rot_x(-30.0),
		"upper_arm_l": _rot_x(-25.0),
		"forearm_l": _rot_x(-20.0),
		"chest": _rot_x(-3.0),
	}


func _melee_hold_pose() -> Dictionary:
	return {
		"upper_arm_r": _rot_x(-40.0),
		"forearm_r": _rot_x(-60.0),
		"upper_arm_l": _rot_x(-15.0),
		"forearm_l": _rot_x(-10.0),
	}


func _create_hold_anim(pose: Dictionary) -> Animation:
	var anim := Animation.new()
	anim.length = 0.1
	anim.loop_mode = Animation.LOOP_LINEAR
	for bone_name in pose:
		_bone_rot(anim, bone_name, [0.0], [pose[bone_name]])
	return anim


func _create_fire_anim(base_pose: Dictionary, recoil_deg: float) -> Animation:
	var anim := Animation.new()
	anim.length = 0.1
	anim.loop_mode = Animation.LOOP_NONE
	var recoil := _rot_x(recoil_deg)
	for bone_name in base_pose:
		var base_q: Quaternion = base_pose[bone_name]
		if bone_name.begins_with("upper_arm"):
			var kicked := base_q * recoil
			_bone_rot(anim, bone_name, [0.0, 0.03, 0.1], [base_q, kicked, base_q])
		else:
			_bone_rot(anim, bone_name, [0.0, 0.1], [base_q, base_q])
	return anim


func _create_melee_slash_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_NONE
	var arm_back := _rot_x(-30.0) * _rot_y(30.0)
	var arm_swing := _rot_x(-50.0) * _rot_y(-40.0)
	var arm_end := _rot_x(-40.0) * _rot_y(-20.0)
	var fa_tight := _rot_x(-80.0)
	var fa_ext := _rot_x(-40.0)
	_bone_rot(anim, "upper_arm_r",
		[0.0, 0.05, 0.15, 0.4],
		[arm_back, arm_back, arm_swing, arm_end])
	_bone_rot(anim, "forearm_r",
		[0.0, 0.05, 0.15, 0.4],
		[fa_tight, fa_tight, fa_ext, _rot_x(-60.0)])
	_bone_rot(anim, "chest",
		[0.0, 0.05, 0.15, 0.4],
		[_rot_y(10.0), _rot_y(15.0), _rot_y(-15.0), Quaternion.IDENTITY])
	return anim


func _create_switch_anim() -> Animation:
	var anim := Animation.new()
	anim.length = 0.5
	anim.loop_mode = Animation.LOOP_NONE
	var down_r := _rot_x(-20.0)
	var down_l := _rot_x(-15.0)
	var down_f := _rot_x(-10.0)
	var mid_r := _rot_x(-60.0)
	var mid_l := _rot_x(-50.0)
	var mid_f := _rot_x(-30.0)
	_bone_rot(anim, "upper_arm_r",
		[0.0, 0.2, 0.5], [mid_r, down_r, mid_r])
	_bone_rot(anim, "forearm_r",
		[0.0, 0.2, 0.5], [mid_f, down_f, mid_f])
	_bone_rot(anim, "upper_arm_l",
		[0.0, 0.2, 0.5], [mid_l, down_l, mid_l])
	_bone_rot(anim, "forearm_l",
		[0.0, 0.2, 0.5], [_rot_x(-25.0), down_f, _rot_x(-25.0)])
	return anim


# --- Static rotation helpers ---


static func _rot_x(deg: float) -> Quaternion:
	return Quaternion(Vector3.RIGHT, deg_to_rad(deg))


static func _rot_y(deg: float) -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(deg))


static func _rot_z(deg: float) -> Quaternion:
	return Quaternion(Vector3.BACK, deg_to_rad(deg))


# --- Movement and combat ---


func update_movement(local_velocity: Vector3, _on_ground: bool) -> void:
	if not anim_tree or not anim_tree.active:
		return
	var horiz_speed := Vector2(local_velocity.x, local_velocity.z).length()
	var speed_norm := clampf(horiz_speed / MC.GROUND_SPEED_CLAMP, 0.0, 1.0)
	anim_tree.set(&"parameters/stand_blend/blend_amount", speed_norm)
	anim_tree.set(&"parameters/crouch_speed/blend_amount", speed_norm)


func apply_weapon_state(weapon_idx: int, ammo_mag: int) -> void:
	if not anim_tree or not anim_tree.active:
		return

	var category: String = WEAPON_CATEGORY.get(weapon_idx, "rifle")

	if _current_weapon_idx < 0:
		_current_weapon_idx = weapon_idx
		_prev_ammo = ammo_mag
		if _weapon_hold_node:
			_weapon_hold_node.animation = HOLD_ANIM_MAP.get(category, &"rifle_hold")
		set_weapon_model(weapon_idx)
		return

	if weapon_idx != _current_weapon_idx:
		_current_weapon_idx = weapon_idx
		_prev_ammo = ammo_mag
		if _weapon_hold_node:
			_weapon_hold_node.animation = HOLD_ANIM_MAP.get(category, &"rifle_hold")
		if _weapon_action_node:
			_weapon_action_node.animation = &"weapon_switch"
		anim_tree.set(&"parameters/weapon_oneshot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		set_weapon_model(weapon_idx)
		return

	if _prev_ammo >= 0 and ammo_mag < _prev_ammo:
		if _weapon_action_node:
			_weapon_action_node.animation = FIRE_ANIM_MAP.get(category, &"rifle_fire")
		anim_tree.set(&"parameters/weapon_oneshot/request",
			AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	_prev_ammo = ammo_mag


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
	if not _is_fallback:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat


# --- Weapons ---


func set_weapon_model(weapon_idx: int) -> void:
	if current_weapon_visual:
		current_weapon_visual.queue_free()
		current_weapon_visual = null

	if not weapon_attach:
		return

	var path: String = WEAPON_MODEL_PATHS.get(weapon_idx, "")
	if path != "":
		var scene: PackedScene = load(path)
		if scene:
			var inst := scene.instantiate()
			inst.name = "WeaponVisual"
			weapon_attach.add_child(inst)
			current_weapon_visual = inst
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


func play_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	if anim_tree:
		anim_tree.active = false
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:x", 90.0, DEATH_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(self, "position:y",
		position.y - 0.4, DEATH_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func reset_death() -> void:
	if not _is_dead:
		return
	_is_dead = false
	rotation_degrees.x = 0.0
	position.y = -MC.HULL_STANDING_HEIGHT * 0.5
	if anim_tree:
		anim_tree.active = true


func is_dead() -> bool:
	return _is_dead


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
