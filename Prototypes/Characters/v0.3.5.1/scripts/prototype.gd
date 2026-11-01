extends Node3D
## A deliberately constructed joint-target pose, not arbitrary rotations.
## Same joint coordinates for both teams. Visual capsule is not gameplay collision.
const STAND_H := 1.829
const CROUCH_H := 0.914
const RADIUS := 0.35
var cam: Camera3D
var zoom := 5.0
var orbit := false
var camera_view := 0 # 0 front, 1 left side, 2 rear
var transition_duration := 0.48
var kneel := false
var blend := 0.0
var label: Label
var actors: Array[Dictionary] = []
var time_elapsed := 0.0
var show_collision := true
var show_hitboxes := true
var show_cosmetics := true
var hitbox_group := 0 # 0 all, 1 head, 2 torso, 3 arms, 4 legs
const HITBOX_NAMES := ["ALL", "HEAD", "TORSO", "ARMS", "LEGS"]

func _ready() -> void:
    _world()
    actors.append(_actor(-0.83, true))
    actors.append(_actor(0.83, false))
    _hud()
    _pose(0.0)

func _world() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.075, 0.095, 0.125)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.85,0.87,0.9)
    env.ambient_light_energy = 0.9
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50,-25,0)
    sun.light_energy = 1.8
    add_child(sun)
    _cube(self, Vector3(0,-0.04,0), Vector3(6,0.08,4), Color(0.22,0.25,0.29))
    cam = Camera3D.new()
    add_child(cam)
    _camera()
    cam.current = true

func _camera() -> void:
    match camera_view:
        0: cam.position = Vector3(0, 1.12, zoom)
        1: cam.position = Vector3(-zoom, 1.12, 0)
        2: cam.position = Vector3(0, 1.12, -zoom)
    cam.look_at(Vector3(0,0.85,0))

func _material(c: Color, transparent := false) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = 0.85
    if transparent:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    return m

func _cube(parent: Node3D, pos: Vector3, dims: Vector3, c: Color) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var m := BoxMesh.new()
    m.size = dims
    n.mesh = m
    n.material_override = _material(c)
    n.position = pos
    parent.add_child(n)
    return n

func _segment(parent: Node3D, c: Color, width: float) -> MeshInstance3D:
    var n := _cube(parent, Vector3.ZERO, Vector3(width,1.0,width), c)
    return n

func _place_segment(n: MeshInstance3D, a: Vector3, b: Vector3, width: float) -> void:
    var d := b-a
    n.position = (a+b)*0.5
    n.quaternion = Quaternion(Vector3.UP,d.normalized()) if d.length() > 0.0001 else Quaternion.IDENTITY
    var bm := n.mesh as BoxMesh
    bm.size = Vector3(width,1.0,width)
    n.scale = Vector3(1.0,d.length(),1.0)

func _actor(x: float, angel: bool) -> Dictionary:
    var root := Node3D.new()
    root.position.x = x
    root.name = "A1_Templar" if angel else "D1_Brute"
    add_child(root)
    var visual := Node3D.new()
    visual.name = "Visual"
    root.add_child(visual)
    var primary := Color(0.83,0.85,0.80) if angel else Color(0.26,0.27,0.30)
    var accent := Color(0.26,0.49,0.77) if angel else Color(0.75,0.19,0.17)
    var pieces := {}
    for part in ["torso","pelvis","head","l_thigh","l_shin","r_thigh","r_shin","l_arm","r_arm","l_forearm","r_forearm"]:
        pieces[part] = _segment(visual,accent if part in ["pelvis","l_shin","r_shin"] else primary, 0.13)
    pieces["l_foot"] = _cube(visual,Vector3.ZERO,Vector3(0.16,0.10,0.24),accent)
    pieces["r_foot"] = _cube(visual,Vector3.ZERO,Vector3(0.16,0.10,0.24),accent)
    var head_detail := Node3D.new()
    visual.add_child(head_detail)
    if angel:
        var ring := TorusMesh.new()
        ring.inner_radius = 0.10
        ring.outer_radius = 0.13
        var halo := MeshInstance3D.new()
        halo.mesh = ring
        halo.material_override = _material(Color(1.0,0.77,0.26))
        halo.position.y = 0.12
        head_detail.add_child(halo)
    else:
        _cube(head_detail,Vector3(-0.075,0.105,0),Vector3(0.055,0.11,0.06),accent)
        _cube(head_detail,Vector3(0.075,0.105,0),Vector3(0.055,0.11,0.06),accent)
    var cap := MeshInstance3D.new()
    var cm := CapsuleMesh.new()
    cm.radius = RADIUS
    cm.height = STAND_H
    cap.mesh = cm
    cap.material_override = _material(Color(0.35,0.8,1.0,0.13),true)
    cap.position.y = STAND_H*0.5
    root.add_child(cap)
    var marker := _cube(root,Vector3.ZERO,Vector3(0.08,0.015,0.08),Color(0.9,0.8,0.2))
    # Combat volumes are illustrative overlays, separate from the movement capsule.
    # All volumes share the exact same dimensions for Angels and Demons.
    var hitboxes := {}
    for part in ["head","torso","pelvis","l_arm","r_arm","l_forearm","r_forearm","l_thigh","r_thigh","l_shin","r_shin"]:
        var h := MeshInstance3D.new()
        h.name = "Damage_" + part
        var mesh := BoxMesh.new()
        mesh.size = Vector3.ONE
        h.mesh = mesh
        h.material_override = _material(Color(1.0,0.18,0.18,0.09),true)
        root.add_child(h)
        hitboxes[part] = h
    return {"root":root,"visual":visual,"parts":pieces,"detail":head_detail,"capsule":cap,"marker":marker,"hitboxes":hitboxes}

func _joint_positions(c: bool) -> Dictionary:
    # Negative Z points forward toward the camera. All coordinates in meters.
    if c:
        return {
            "hip":Vector3(0,0.43,0.02),
            "shoulder":Vector3(0,0.67,-0.015),
            "neck":Vector3(0,0.72,-0.02),
            "head":Vector3(0,0.80,-0.02),
            "lk":Vector3(-0.12,0.43,-0.34),
            "lf":Vector3(-0.12,0.095,-0.48),
            "rk":Vector3(0.12,0.085,0.16),
            "rf":Vector3(0.12,0.095,0.40),
            "le":Vector3(-0.29,0.47,-0.13),
            "re":Vector3(0.29,0.47,-0.13),
            "lh":Vector3(-0.25,0.41,-0.24),
            "rh":Vector3(0.25,0.41,-0.24)
        }
    return {
        "hip":Vector3(0,0.90,0),
        "shoulder":Vector3(0,1.42,0),
        "neck":Vector3(0,1.51,0),
        "head":Vector3(0,1.63,0),
        "lk":Vector3(-0.12,0.48,0),
        "lf":Vector3(-0.12,0.095,-0.03),
        "rk":Vector3(0.12,0.48,0),
        "rf":Vector3(0.12,0.095,-0.03),
        "le":Vector3(-0.31,1.18,0),
        "re":Vector3(0.31,1.18,0),
        "lh":Vector3(-0.30,0.97,-0.05),
        "rh":Vector3(0.30,0.97,-0.05)
    }

func _interpolate_joints(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
    var result := {}
    for k in a.keys(): result[k] = a[k].lerp(b[k],t)
    return result

func _pose(_t: float) -> void:
    var smooth_blend := blend * blend * (3.0 - 2.0 * blend)
    var p := _interpolate_joints(_joint_positions(false),_joint_positions(true),smooth_blend)
    for a in actors:
        var parts: Dictionary = a["parts"]
        _place_segment(parts["torso"],p["hip"]+Vector3(0,0.10,0),p["shoulder"],0.36)
        _place_segment(parts["pelvis"],p["hip"]+Vector3(0,-0.08,0),p["hip"]+Vector3(0,0.05,0),0.32)
        _place_segment(parts["head"],p["head"]+Vector3(0,-0.06,0),p["head"]+Vector3(0,0.06,0),0.22)
        for prefix in ["l","r"]:
            var side := -1.0 if prefix == "l" else 1.0
            var hip_side: Vector3 = p["hip"]+Vector3(side*0.12,0,0)
            var shoulder_side: Vector3 = p["shoulder"]+Vector3(side*0.245,0,0)
            _place_segment(parts[prefix+"_thigh"],hip_side,p[prefix+"k"],0.17)
            _place_segment(parts[prefix+"_shin"],p[prefix+"k"],p[prefix+"f"],0.15)
            _place_segment(parts[prefix+"_arm"],shoulder_side,p[prefix+"e"],0.12)
            _place_segment(parts[prefix+"_forearm"],p[prefix+"e"],p[prefix+"h"],0.12)
            parts[prefix+"_foot"].position = p[prefix+"f"]+Vector3(0,-0.025,-0.045)
        a["detail"].position = p["head"]+Vector3(0,0.075,0)
        a["detail"].visible = show_cosmetics
        var boxes: Dictionary = a["hitboxes"]
        _place_segment(boxes["torso"],p["hip"]+Vector3(0,0.10,0),p["shoulder"],0.34)
        _place_segment(boxes["pelvis"],p["hip"]+Vector3(0,-0.08,0),p["hip"]+Vector3(0,0.05,0),0.30)
        _place_segment(boxes["head"],p["head"]+Vector3(0,-0.06,0),p["head"]+Vector3(0,0.06,0),0.20)
        for prefix in ["l","r"]:
            var side := -1.0 if prefix == "l" else 1.0
            var hip_side: Vector3 = p["hip"]+Vector3(side*0.12,0,0)
            var shoulder_side: Vector3 = p["shoulder"]+Vector3(side*0.245,0,0)
            _place_segment(boxes[prefix+"_thigh"],hip_side,p[prefix+"k"],0.15)
            _place_segment(boxes[prefix+"_shin"],p[prefix+"k"],p[prefix+"f"],0.13)
            _place_segment(boxes[prefix+"_arm"],shoulder_side,p[prefix+"e"],0.10)
            _place_segment(boxes[prefix+"_forearm"],p[prefix+"e"],p[prefix+"h"],0.10)
        for part_name in boxes.keys():
            var category := 2
            if part_name == "head": category = 1
            elif part_name.contains("arm"): category = 3
            elif part_name.contains("thigh") or part_name.contains("shin"): category = 4
            boxes[part_name].visible = show_hitboxes and (hitbox_group == 0 or hitbox_group == category)
        var cap: MeshInstance3D = a["capsule"]
        var cm: CapsuleMesh = cap.mesh
        cm.height = lerpf(STAND_H,CROUCH_H,smooth_blend)
        cap.position.y = cm.height*0.5
        cap.visible = show_collision
    # At full crouch, head top ~0.86 m; horn/halo must be visually checked.

func _process(delta: float) -> void:
    time_elapsed += delta
    blend = move_toward(blend,1.0 if kneel else 0.0,delta / transition_duration)
    _pose(time_elapsed)
    if orbit:
        for a in actors: a["visual"].rotate_y(delta*0.55)
    var eased := blend * blend * (3.0 - 2.0 * blend)
    var head_top := lerpf(1.765, 0.86, eased)
    # Halo and horns are decorative; their height does not expand combat hitboxes.
    var highest_accessory := head_top + (0.115 if eased > 0.001 else 0.115)
    var limit := lerpf(STAND_H, CROUCH_H, eased)
    var clearance := limit - highest_accessory
    var status := "COSMETIC OVER HEIGHT (ALLOWED)" if clearance < 0.0 else "COSMETIC WITHIN HEIGHT"
    label.text = "POSE: %s | transition %.0f%% | %s | margin %.3f m" % ["ONE-KNEE" if kneel else "STAND", eased*100.0, status, clearance]

func _unhandled_input(e: InputEvent) -> void:
    if e is InputEventMouseButton and e.pressed:
        if e.button_index == MOUSE_BUTTON_WHEEL_UP: _zoom(-0.4)
        if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: _zoom(0.4)
    if e is InputEventKey and e.pressed and not e.echo:
        match e.keycode:
            KEY_B: show_collision = not show_collision
            KEY_H: show_hitboxes = not show_hitboxes
            KEY_G: show_cosmetics = not show_cosmetics
            KEY_J: hitbox_group = (hitbox_group + 1) % HITBOX_NAMES.size()
            KEY_C: kneel = true
            KEY_V: kneel = false
            KEY_1: camera_view = 0; orbit = false; _camera()
            KEY_2: camera_view = 1; orbit = false; _camera()
            KEY_3: camera_view = 2; orbit = false; _camera()
            KEY_R: orbit = true
            KEY_T: orbit = false
            KEY_EQUAL,KEY_KP_ADD: _zoom(-0.4)
            KEY_MINUS,KEY_KP_SUBTRACT: _zoom(0.4)
            KEY_0,KEY_KP_0: zoom = 5.0; _camera()

func _zoom(d: float) -> void:
    zoom = clampf(zoom+d,2.0,9.0)
    _camera()

func _hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := VBoxContainer.new()
    panel.position = Vector2(20,15)
    layer.add_child(panel)
    var title := Label.new()
    title.text = "ANGELS & DEMONS | HITBOX VISUALIZER v0.3.5"
    panel.add_child(title)
    label = Label.new()
    panel.add_child(label)
    var help := Label.new()
    help.text = "C Kneel  |  V Stand  |  1 Front  2 Side  3 Rear\nR Rotate  |  T Stop  |  Mouse wheel / +/- Zoom  |  0 Reset\nB Capsule (blue)  |  H Damage zones (red)  |  G Cosmetics (gold)  |  J Cycle hitbox groups.\nLeft foot forward / right knee down. Cosmetics do NOT receive damage.\nDebug visuals only: no actual physics collision, hit detection, or networking."
    panel.add_child(help)
