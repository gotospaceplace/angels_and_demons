extends Node3D
## Rigging test: identical Skeleton3D hierarchy on both faction mannequins.
## Rigid meshes follow BoneAttachment3D nodes. Not skinned production geometry.
const STAND_HEIGHT := 1.829
const CROUCH_HEIGHT := 0.914
const RADIUS := 0.35
var camera: Camera3D
var zoom_distance := 5.7
var spin := false
var crouched := false
var crouch_style := "kneel"
var clearance_text := ""
var action := "idle"
var elapsed := 0.0
var characters: Array[Node3D] = []
var label: Label
var bones := {}
var rigs: Array[Skeleton3D] = []

func _ready() -> void:
    _environment()
    characters.append(_character("A1 Templar", -0.9, true))
    characters.append(_character("D1 Brute", 0.9, false))
    _ui()
    _apply_pose(0.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom(-0.45)
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom(0.45)
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_EQUAL, KEY_KP_ADD: _zoom(-0.45)
            KEY_MINUS, KEY_KP_SUBTRACT: _zoom(0.45)
            KEY_0, KEY_KP_0:
                zoom_distance = 5.7
                _camera_update()
            KEY_C: crouched = true
            KEY_V: crouched = false
            KEY_K: crouch_style = "squat" if crouch_style == "kneel" else "kneel"
            KEY_1: action = "idle"
            KEY_2: action = "walk"
            KEY_3: action = "run"
            KEY_4: action = "jump"
            KEY_R: spin = true
            KEY_T: spin = false

func _zoom(amount: float) -> void:
    zoom_distance = clampf(zoom_distance + amount, 2.0, 9.0)
    _camera_update()

func _camera_update() -> void:
    camera.position = Vector3(0, 1.6, zoom_distance)
    camera.look_at(Vector3(0, 0.95, 0))

func _process(delta: float) -> void:
    elapsed += delta
    _apply_pose(elapsed)
    if spin:
        for c in characters: c.get_node("Visual").rotate_y(delta * 0.5)
    label.text = "Pose: %s | %s | shared rig (floor-aligned preview)" % ["CROUCH" if crouched else "STAND", action.to_upper()]

func _environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.085, 0.11, 0.15)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.7, 0.75, 0.85)
    env.ambient_light_energy = 0.7
    world.environment = env
    add_child(world)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, -25, 0)
    light.light_energy = 1.8
    add_child(light)
    camera = Camera3D.new()
    _camera_update()
    camera.current = true
    add_child(camera)
    _box(self,"Floor",Vector3(0,-0.035,0),Vector3(6,0.07,3),Color(0.18,0.2,0.23))

func _mat(color: Color, alpha := 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = Color(color.r,color.g,color.b,alpha)
    m.roughness = 0.85
    if alpha < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _box(parent: Node3D, name_: String, p: Vector3, size: Vector3, color: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = name_
    node.mesh = mesh
    node.material_override = _mat(color)
    node.position = p
    parent.add_child(node)

func _bone(s: Skeleton3D, name_: String, parent_: int, origin: Vector3) -> int:
    var idx := s.get_bone_count()
    s.add_bone(name_)
    if parent_ >= 0: s.set_bone_parent(idx,parent_)
    s.set_bone_rest(idx,Transform3D(Basis.IDENTITY,origin))
    return idx

func _attached(s: Skeleton3D, idx: int, name_: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var a := BoneAttachment3D.new()
    a.name = name_ + "Attachment"
    a.bone_name = s.get_bone_name(idx)
    s.add_child(a)
    _box(a,name_,pos,size,color)

func _character(name_: String, x: float, angel: bool) -> Node3D:
    var root := Node3D.new()
    root.name = name_.replace(" ","")
    root.position.x = x
    add_child(root)
    var visual := Node3D.new()
    visual.name = "Visual"
    root.add_child(visual)
    var s := Skeleton3D.new()
    s.name = "SharedSkeleton"
    visual.add_child(s)
    rigs.append(s)
    # Rest offsets are relative to each parent, not world coordinates.
    var hips := _bone(s,"Hips",-1,Vector3(0,0.82,0))
    var spine := _bone(s,"Spine",hips,Vector3(0,0.27,0))
    var chest := _bone(s,"Chest",spine,Vector3(0,0.22,0))
    var neck := _bone(s,"Neck",chest,Vector3(0,0.20,0))
    var head := _bone(s,"Head",neck,Vector3(0,0.08,0))
    var lu := _bone(s,"LeftUpperArm",chest,Vector3(-0.265,0.10,0))
    var ll := _bone(s,"LeftLowerArm",lu,Vector3(0,-0.27,0))
    var ru := _bone(s,"RightUpperArm",chest,Vector3(0.265,0.10,0))
    var rl := _bone(s,"RightLowerArm",ru,Vector3(0,-0.27,0))
    var lt := _bone(s,"LeftThigh",hips,Vector3(-0.115,-0.06,0))
    var ls := _bone(s,"LeftShin",lt,Vector3(0,-0.37,0))
    var lf := _bone(s,"LeftFoot",ls,Vector3(0,-0.30,-0.04))
    var rt := _bone(s,"RightThigh",hips,Vector3(0.115,-0.06,0))
    var rs := _bone(s,"RightShin",rt,Vector3(0,-0.37,0))
    var rf := _bone(s,"RightFoot",rs,Vector3(0,-0.30,-0.04))
    var primary := Color(0.83,0.85,0.79) if angel else Color(0.23,0.23,0.25)
    var accent := Color(0.25,0.48,0.71) if angel else Color(0.72,0.16,0.13)
    _attached(s,hips,"Pelvis",Vector3.ZERO,Vector3(0.38,0.19,0.23),accent)
    _attached(s,spine,"Torso",Vector3(0,0.10,0),Vector3(0.43,0.40,0.23),primary)
    _attached(s,head,"Head",Vector3(0,0.07,0),Vector3(0.22,0.27,0.22),primary)
    for pair in [[lu,ll,lt,ls,lf,-1.0],[ru,rl,rt,rs,rf,1.0]]:
        _attached(s,pair[0],"UpperArm",Vector3(0,-0.13,0),Vector3(0.12,0.26,0.16),primary)
        _attached(s,pair[1],"Forearm",Vector3(0,-0.13,0),Vector3(0.12,0.26,0.16),primary)
        _attached(s,pair[2],"Thigh",Vector3(0,-0.17,0),Vector3(0.16,0.34,0.19),primary)
        _attached(s,pair[3],"Shin",Vector3(0,-0.14,0),Vector3(0.16,0.29,0.19),primary)
        _attached(s,pair[4],"Boot",Vector3(0,-0.02,-0.04),Vector3(0.18,0.15,0.27),accent)
    if angel:
        var a := BoneAttachment3D.new()
        a.bone_name = "Head"
        s.add_child(a)
        var halo := MeshInstance3D.new()
        var ring := TorusMesh.new()
        ring.inner_radius = 0.105
        ring.outer_radius = 0.13
        halo.mesh = ring
        halo.material_override = _mat(Color(0.95,0.72,0.29))
        halo.position = Vector3(0,0.265,0)
        a.add_child(halo)
    else:
        for side in [-1.0,1.0]:
            var a := BoneAttachment3D.new()
            a.bone_name = "Head"
            s.add_child(a)
            _box(a,"Horn",Vector3(side*0.075,0.21,0),Vector3(0.06,0.12,0.065),accent)
    var cap := MeshInstance3D.new()
    cap.name = "ReferenceCapsule"
    var mesh := CapsuleMesh.new()
    mesh.radius = RADIUS
    mesh.height = STAND_HEIGHT
    cap.mesh = mesh
    cap.material_override = _mat(Color(0.4,0.8,0.95),0.11)
    cap.position.y = STAND_HEIGHT*0.5
    root.add_child(cap)
    return root

func _rot(s: Skeleton3D, bone: String, angle: float) -> void:
    var idx := s.find_bone(bone)
    s.set_bone_pose_rotation(idx,Quaternion(Vector3.RIGHT,angle))

func _apply_pose(t: float) -> void:
    var speed := 0.0
    if action == "walk": speed = 5.0
    if action == "run": speed = 9.0
    var swing := sin(t*speed) if speed > 0.0 else 0.0
    for i in rigs.size():
        var s := rigs[i]
        s.reset_bone_poses()
        var hips := s.find_bone("Hips")
        var pos := Vector3.ZERO
        var kneeling := crouched and crouch_style == "kneel"
        if crouched:
            # The lowered hips and asymmetric leg joints form a compact
            # one-knee pose. Both teams use the exact same joint rotations.
            pos.y = -0.55 if kneeling else -0.47
        if action == "jump" and not crouched:
            pos.y = maxf(0.0,sin(t*3.0))*0.10
        s.set_bone_pose_position(hips,pos)
        if kneeling:
            # Left knee is the grounded knee, right leg folds forward.
            _rot(s,"Spine",0.46)
            _rot(s,"Chest",0.22)
            _rot(s,"LeftThigh",-1.12)
            _rot(s,"LeftShin",1.92)
            _rot(s,"RightThigh",-0.48)
            _rot(s,"RightShin",1.13)
            _rot(s,"LeftUpperArm",0.37)
            _rot(s,"RightUpperArm",0.37)
        elif crouched:
            _rot(s,"Spine",0.28)
            _rot(s,"Chest",0.18)
            _rot(s,"LeftThigh",-0.82)
            _rot(s,"RightThigh",-0.82)
            _rot(s,"LeftShin",1.45)
            _rot(s,"RightShin",1.45)
            _rot(s,"LeftUpperArm",0.25)
            _rot(s,"RightUpperArm",0.25)
        else:
            _rot(s,"LeftThigh",swing*0.38)
            _rot(s,"RightThigh",-swing*0.38)
            _rot(s,"LeftShin",maxf(0.0,-swing)*0.35)
            _rot(s,"RightShin",maxf(0.0,swing)*0.35)
            _rot(s,"LeftUpperArm",0.25-swing*0.3)
            _rot(s,"RightUpperArm",0.25+swing*0.3)
        _rot(s,"LeftLowerArm",-0.18)
        _rot(s,"RightLowerArm",-0.18)
        var cap: MeshInstance3D = characters[i].get_node("ReferenceCapsule")
        var capmesh: CapsuleMesh = cap.mesh
        capmesh.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
        cap.position.y = capmesh.height*0.5
        # Floor alignment: evaluate actual mesh vertices in world space, not
        # just the hips bone. This prevents feet clipping below the floor.
        s.force_update_all_bone_transforms()
        var visual: Node3D = characters[i].get_node("Visual")
        visual.position.y = 0.0
        var lowest := INF
        for node in visual.find_children("*", "MeshInstance3D", true, false):
            var part := node as MeshInstance3D
            var bounds := part.get_aabb()
            for corner in range(8):
                var point := bounds.get_endpoint(corner)
                var world_point := part.global_transform * point
                lowest = minf(lowest, world_point.y)
        if lowest < INF:
            # Jump previews intentionally leave the ground.
            var airborne := maxf(0.0, sin(t * 3.0)) * 0.10 if action == "jump" and not crouched else 0.0
            visual.position.y = -lowest + airborne
        # Diagnostic only: this visual rig is not guaranteed to fit the
        # actual crouch capsule. Measure the next production skinned rig.
        if i == 0:
            var highest := -INF
            var max_horizontal := 0.0
            for node in visual.find_children("*", "MeshInstance3D", true, false):
                var part := node as MeshInstance3D
                var bounds := part.get_aabb()
                for corner in range(8):
                    var point := part.global_transform * bounds.get_endpoint(corner)
                    highest = maxf(highest,point.y)
                    max_horizontal = maxf(max_horizontal, Vector2(point.x-characters[i].global_position.x,point.z-characters[i].global_position.z).length())
            var limit := CROUCH_HEIGHT if crouched else STAND_HEIGHT
            clearance_text = "Visual envelope: H %.2fm / limit %.3fm | radius %.2fm / limit %.2fm%s" % [highest,limit,max_horizontal,RADIUS,"  (OUTSIDE GUIDE)" if highest > limit + 0.01 or max_horizontal > RADIUS + 0.01 else "  (within AABB sample)"]

func _ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var panel := VBoxContainer.new()
    panel.position = Vector2(20,18)
    ui.add_child(panel)
    var heading := Label.new()
    heading.text = "ANGELS & DEMONS | ANIMATION / KNEEL PROTOTYPE v0.3"
    panel.add_child(heading)
    label = Label.new()
    panel.add_child(label)
    var help := Label.new()
    help.text = "1 Idle   2 Walk   3 Run   4 Jump\nC Crouch   V Stand   K Toggle kneel/squat\nR Rotate   T Stop\nMouse wheel / +/- Zoom   0 Reset\nNOTE: Bone-driven rigid mannequin preview, not skinned production model.\nCapsule is reference only; animation clearance needs in-engine verification."
    panel.add_child(help)
