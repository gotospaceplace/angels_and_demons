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
var weapon_idx: int = 2
var ammo_mag: int = 30
var is_dead: bool = false

var snapshot_history: Array = []
var acked_snapshot_tick: int = 0

var fire_pressed: bool = false
var next_fire_tick: int = 0

var kills: int = 0
var deaths: int = 0
var respawn_tick: int = 0


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
	body.set_physics_process(false)

	last_input = NetInput.new()


func queue_input(cmd: NetInput) -> void:
	if cmd.tick <= last_acked_tick:
		return
	for i in range(input_buffer.size() - 1, -1, -1):
		if input_buffer[i].tick >= cmd.tick:
			return
	if input_buffer.size() >= NetConstants.SERVER_INPUT_BUFFER:
		input_buffer.pop_front()
	input_buffer.append(cmd)


func dequeue_input(current_tick: int) -> void:
	var cmd: NetInput

	while input_buffer.size() > 0 and input_buffer[0].tick < current_tick:
		last_input = input_buffer.pop_front()
		last_acked_tick = maxi(last_acked_tick, last_input.tick)

	if input_buffer.size() > 0 and input_buffer[0].tick == current_tick:
		cmd = input_buffer.pop_front()
		last_input = cmd
		last_acked_tick = maxi(last_acked_tick, cmd.tick)
	else:
		cmd = last_input

	if is_dead:
		body.apply_network_input(cmd.yaw, cmd.pitch,
			false, false, false, false, false, false)
		body.simulate_tick(NetConstants.TICK_INTERVAL)
		return

	_check_weapon_switch(cmd)

	body.apply_network_input(cmd.yaw, cmd.pitch,
		cmd.has_button(NetInput.BIT_FORWARD), cmd.has_button(NetInput.BIT_BACK),
		cmd.has_button(NetInput.BIT_LEFT), cmd.has_button(NetInput.BIT_RIGHT),
		cmd.has_button(NetInput.BIT_JUMP), cmd.has_button(NetInput.BIT_DUCK))
	body.simulate_tick(NetConstants.TICK_INTERVAL)


const WEAPON_MAG_SIZES := [0, 12, 30, 30, 10]  # knife, usp, ak47, m4a1, awp
const WEAPON_COUNT := 5

func _check_weapon_switch(cmd: NetInput) -> void:
	var new_idx := -1
	if cmd.has_button(NetInput.BIT_WEAPON1):
		new_idx = 0
	elif cmd.has_button(NetInput.BIT_WEAPON2):
		new_idx = 1
	elif cmd.has_button(NetInput.BIT_WEAPON3):
		new_idx = 2
	elif cmd.has_button(NetInput.BIT_WEAPON4):
		new_idx = 3
	elif cmd.has_button(NetInput.BIT_WEAPON5):
		new_idx = 4
	if new_idx >= 0 and new_idx < WEAPON_COUNT and new_idx != weapon_idx:
		weapon_idx = new_idx
		ammo_mag = WEAPON_MAG_SIZES[new_idx]
		fire_pressed = false
		next_fire_tick = 0


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


func store_snapshot(tick: int, states: Array) -> void:
	var entry := {"tick": tick, "states": {}}
	for s in states:
		entry["states"][s.peer_id] = s.duplicate_state()
	snapshot_history.append(entry)
	if snapshot_history.size() > NetConstants.SNAPSHOT_BUFFER_SIZE:
		snapshot_history.pop_front()


func get_acked_bases() -> Dictionary:
	if acked_snapshot_tick == 0:
		return {}
	for i in range(snapshot_history.size() - 1, -1, -1):
		if snapshot_history[i]["tick"] == acked_snapshot_tick:
			return snapshot_history[i]["states"]
	return {}


func take_damage(damage: float) -> void:
	if is_dead:
		return
	hp -= int(ceilf(damage))
	if hp <= 0:
		hp = 0
		is_dead = true


func die(current_tick: int) -> void:
	is_dead = true
	hp = 0
	deaths += 1
	fire_pressed = false
	respawn_tick = current_tick + int(NetConstants.RESPAWN_DELAY * float(NetConstants.TICK_RATE))
	var collision := body.get_node_or_null("PlayerCollision")
	if collision:
		collision.disabled = true


func respawn(spawn_pos: Vector3) -> void:
	is_dead = false
	hp = 100
	armor = 0
	weapon_idx = 2
	ammo_mag = 30
	fire_pressed = false
	next_fire_tick = 0
	input_buffer.clear()
	body.global_position = spawn_pos
	body.velocity = Vector3.ZERO
	var collision := body.get_node_or_null("PlayerCollision")
	if collision:
		collision.disabled = false


func destroy() -> void:
	if body and is_instance_valid(body):
		body.queue_free()
