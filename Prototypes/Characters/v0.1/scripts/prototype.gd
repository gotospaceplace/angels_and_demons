extends Node3D
## Visual clearance prototype ONLY. Not a skinned mesh, rig, or production hitbox implementation.
## Ground plane is y=0; all geometry dimensions are in meters.
const STAND_HEIGHT := 1.829
const CROUCH_HEIGHT := 0.914
const HULL_RADIUS := 0.35
const HEAD_TOP := 1.75

var crouched := false
var spin_enabled := false
var angel: Node3D
var demon: Node3D
var camera: Camera3D
var status: Label

func _ready() -> void:
    _make_environment()
    angel = _make_character("A1 Templar", Vector3(-0.9, 0, 0), Color(0.83, 0.85, 0.79), Color(0.25, 0.48, 0.71), true)
    demon = _make_character("D1 Brute", Vector3(0.9, 0, 0), Color(0.23, 0.23, 0.25), Color(0.72, 0.16, 0.13), false)
    _make_ui()
    _set_pose(false)

func _process(delta: float) -> void:
    if Input.is_key_pressed(KEY_C) and not crouched:
        _set_pose(true)
    if Input.is_key_pressed(KEY_V) and crouched:
        _set_pose(false)
    if Input.is_key_pressed(KEY_R):
        spin_enabled = true
    if Input.is_key_pressed(KEY_T):
        spin_enabled = false
    if spin_enabled:
        angel.get_node("Visual").rotate_y(delta * 0.5)
        demon.get_node("Visual").rotate_y(delta * 0.5)

func _make_environment() -> void:
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
    camera.position = Vector3(0, 1.6, 5.7)
    camera.look_at(Vector3(0, 0.95, 0))
    camera.current = true
    add_child(camera)
    _part(self, "Floor", Vector3(0, -0.035, 0), Vector3(6, 0.07, 3), Color(0.18, 0.2, 0.23))

func _material(color: Color, alpha := 1.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(color.r, color.g, color.b, alpha)
    mat.roughness = 0.85
    if alpha < 1.0:
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func _part(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = part_name
    node.mesh = mesh
    node.material_override = _material(color)
    node.position = pos
    parent.add_child(node)
    return node

func _make_character(char_name: String, pos: Vector3, primary: Color, accent: Color, is_angel: bool) -> Node3D:
    var root := Node3D.new()
    root.name = char_name.replace(" ", "")
    root.position = pos
    add_child(root)
    var visual := Node3D.new()
    visual.name = "Visual"
    root.add_child(visual)
    _part(visual, "Torso", Vector3(0, 1.14, 0), Vector3(0.43, 0.55, 0.23), primary)
    _part(visual, "Pelvis", Vector3(0, 0.81, 0), Vector3(0.38, 0.19, 0.23), accent)
    _part(visual, "Head", Vector3(0, 1.58, 0), Vector3(0.22, 0.30, 0.22), primary)
    for side in [-1.0, 1.0]:
        _part(visual, "Arm_%s" % side, Vector3(side * 0.265, 1.10, 0), Vector3(0.12, 0.54, 0.16), primary)
        _part(visual, "Leg_%s" % side, Vector3(side * 0.115, 0.40, 0), Vector3(0.16, 0.76, 0.19), primary)
        _part(visual, "Boot_%s" % side, Vector3(side * 0.115, 0.09, -0.045), Vector3(0.18, 0.18, 0.28), accent)
    if is_angel:
        # Compact halo; highest geometry y=1.81, below standing capsule top.
        var halo := MeshInstance3D.new()
        halo.name = "Halo"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.105
        torus.outer_radius = 0.13
        halo.mesh = torus
        halo.material_override = _material(Color(0.95, 0.72, 0.29))
        halo.position = Vector3(0, 1.79, 0)
        visual.add_child(halo)
    else:
        for side in [-1.0, 1.0]:
            _part(visual, "Horn_%s" % side, Vector3(side * 0.075, 1.735, 0), Vector3(0.06, 0.13, 0.065), accent)
    # The wire capsule is a *visual reference*, not a collision shape or combat hitbox.
    var capsule := MeshInstance3D.new()
    capsule.name = "ReferenceCapsule"
    var cap_mesh := CapsuleMesh.new()
    cap_mesh.radius = HULL_RADIUS
    cap_mesh.height = STAND_HEIGHT
    capsule.mesh = cap_mesh
    capsule.material_override = _material(Color(0.4, 0.8, 0.95), 0.11)
    capsule.position.y = STAND_HEIGHT * 0.5
    root.add_child(capsule)
    return root

func _set_pose(value: bool) -> void:
    crouched = value
    for root in [angel, demon]:
        # Preview-only proportional compression. A real crouch requires joint animation.
        root.get_node("Visual").scale.y = CROUCH_HEIGHT / STAND_HEIGHT if crouched else 1.0
        var capsule: MeshInstance3D = root.get_node("ReferenceCapsule")
        var mesh: CapsuleMesh = capsule.mesh
        mesh.height = CROUCH_HEIGHT if crouched else STAND_HEIGHT
        capsule.position.y = mesh.height * 0.5
    if status:
        status.text = "CROUCH PREVIEW (not a real pose)" if crouched else "STANDING REFERENCE"

func _make_ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var panel := VBoxContainer.new()
    panel.position = Vector2(20, 18)
    ui.add_child(panel)
    var heading := Label.new()
    heading.text = "ANGELS & DEMONS  |  CHARACTER FIT PROTOTYPE"
    panel.add_child(heading)
    status = Label.new()
    panel.add_child(status)
    var hint := Label.new()
    hint.text = "C: crouch preview   V: stand   R: rotate   T: stop rotation\nStanding hull: 1.829 m x 0.700 m | Crouch hull: 0.914 m\nIMPORTANT: Static clearance illustration only; not a rig or validated hitbox."
    panel.add_child(hint)
