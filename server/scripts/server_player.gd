extends RefCounted

const MC = preload("res://shared/scripts/movement_constants.gd")
const PlayerMovement = preload("res://shared/scripts/player_movement.gd")

var peer_id: int
var body: CharacterBody3D
var input_buffer: Array = []
var last_input: NetInput
var last_acked_tick: int = 0
var hp: int = 100
var armor: int = 0
var weapon_idx: int = 0
var ammo_mag: int = 30
var is_dead: bool = false


func create(p_peer_id: int, spawn_pos: Vector3, parent: Node) -> void:
	peer_id = p_peer_id

	body = PlayerMovement.new()
	body.name = "Player_%d" % peer_id

	var collision := CollisionShape3D.new()
	collision.name = "PlayerCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = MC.HULL_STANDING_HEIGHT
	collision.shape = capsule
	body.add_child(collision)

	var head_node := Node3D.new()
	head_node.name = "Head"
	head_node.position.y = MC.VIEW_OFFSET_STANDING
	body.add_child(head_node)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = false
	head_node.add_child(cam)

	body.position = spawn_pos
	body.test_driven = true
	parent.add_child(body)

	last_input = NetInput.new()


func queue_input(cmd: NetInput) -> void:
	if input_buffer.size() >= NetConstants.SERVER_INPUT_BUFFER:
		input_buffer.pop_front()
	input_buffer.append(cmd)


func dequeue_input() -> void:
	var cmd: NetInput
	if input_buffer.size() > 0:
		cmd = input_buffer.pop_front()
		last_input = cmd
		last_acked_tick = cmd.tick
	else:
		cmd = last_input

	body.apply_network_input(cmd.yaw, cmd.pitch,
		cmd.has_button(NetInput.BIT_FORWARD), cmd.has_button(NetInput.BIT_BACK),
		cmd.has_button(NetInput.BIT_LEFT), cmd.has_button(NetInput.BIT_RIGHT),
		cmd.has_button(NetInput.BIT_JUMP), cmd.has_button(NetInput.BIT_DUCK))


func get_snapshot(tick: int) -> NetSnapshot:
	var s := NetSnapshot.new()
	s.peer_id = peer_id
	s.tick = tick
	s.position = body.global_position
	s.velocity = body.velocity
	s.yaw = fposmod(rad_to_deg(body.rotation.y), 360.0)
	s.pitch = rad_to_deg(body.get_node("Head").rotation.x)
	s.set_flag(NetSnapshot.FLAG_ON_GROUND, body.on_ground)
	s.set_flag(NetSnapshot.FLAG_IS_DUCKED, body.is_ducked)
	s.set_flag(NetSnapshot.FLAG_IS_DEAD, is_dead)
	s.hp = hp
	s.armor = armor
	s.weapon_idx = weapon_idx
	s.ammo_mag = ammo_mag
	return s


func destroy() -> void:
	if body and is_instance_valid(body):
		body.queue_free()
