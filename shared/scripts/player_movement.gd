extends CharacterBody3D

const MC := preload("res://shared/scripts/movement_constants.gd")
const MOUSE_SENSITIVITY := 0.002

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var standing_collision: CollisionShape3D = $PlayerCollision

var wish_dir := Vector3.ZERO
var wish_speed := 0.0
var max_speed := MC.SPEED_KNIFE
var on_ground := false
var was_on_ground := false
var jump_pressed := false
var jump_was_pressed := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	_read_input()
	_categorize_position()

	if on_ground:
		_ground_move(delta)
	else:
		_air_move(delta)

	_categorize_position()

	# Post-move half gravity
	if not on_ground:
		velocity.y -= MC.GRAVITY * delta * 0.5
	else:
		velocity.y = 0.0

func _read_input() -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	var wish_vel := forward * (-input_dir.y) + right * input_dir.x
	wish_speed = wish_vel.length() * max_speed

	if wish_vel.length() > 0.001:
		wish_dir = wish_vel.normalized()
	else:
		wish_dir = Vector3.ZERO

	jump_was_pressed = jump_pressed
	jump_pressed = Input.is_action_pressed("jump")

func _categorize_position() -> void:
	was_on_ground = on_ground

	# Use is_on_floor() after a zero-length move to let Godot's internal
	# floor detection work, plus a raycast as backup
	if velocity.y > 0.0:
		on_ground = false
		return

	var space_state := get_world_3d().direct_space_state
	var from := global_position
	var to := from + Vector3(0, -0.1, 0)
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.exclude = [get_rid()]

	var result := space_state.intersect_ray(params)
	if result and result.normal.y >= MC.FLOOR_NORMAL_MIN:
		on_ground = true
		# Snap to ground to prevent floating
		if not was_on_ground and velocity.y <= 0.0:
			var snap_dist := from.y - result.position.y
			if snap_dist > 0.0 and snap_dist < 0.15:
				global_position.y = result.position.y
	else:
		on_ground = false

func _ground_move(delta: float) -> void:
	# Pre-move half gravity
	velocity.y -= MC.GRAVITY * delta * 0.5
	velocity.y = 0.0

	# Jump check: must release and re-press (anti-pogo)
	if jump_pressed and not jump_was_pressed and on_ground:
		velocity.y = MC.JUMP_SPEED
		on_ground = false
		return

	# Friction
	_apply_friction(delta)

	# Ground acceleration
	_apply_ground_acceleration(delta)

	# Walk move with stair stepping
	_walk_move(delta)

func _air_move(delta: float) -> void:
	# Pre-move half gravity
	velocity.y -= MC.GRAVITY * delta * 0.5

	# Air acceleration
	_apply_air_acceleration(delta)

	# Fly move (slide against surfaces)
	_fly_move(delta)

func _apply_friction(delta: float) -> void:
	var speed := Vector3(velocity.x, 0, velocity.z).length()
	if speed < MC.STOP_EPSILON:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var control := maxf(speed, MC.STOPSPEED)

	# Edge friction check
	var friction := MC.FRICTION
	if _check_edge_friction():
		friction *= MC.EDGE_FRICTION

	var drop := control * friction * delta
	var new_speed := maxf(0.0, speed - drop)
	var factor := new_speed / speed

	velocity.x *= factor
	velocity.z *= factor

func _check_edge_friction() -> bool:
	# Trace forward at foot level to detect edges
	var hvel := Vector3(velocity.x, 0, velocity.z)
	if hvel.length() < MC.STOP_EPSILON:
		return false

	var trace_dir := hvel.normalized()
	var start := global_position + trace_dir * MC.EDGE_FRICTION_TRACE_DIST

	# Cast downward from that point
	var params := PhysicsRayQueryParameters3D.create(
		start,
		start + Vector3(0, -MC.HULL_STANDING_HEIGHT * 0.5 - MC.GROUND_TRACE_DIST, 0)
	)
	params.exclude = [get_rid()]

	var space_state := get_world_3d().direct_space_state
	var result := space_state.intersect_ray(params)

	return result.is_empty()

func _apply_ground_acceleration(delta: float) -> void:
	if wish_dir.length() < 0.001:
		return

	var current_speed := velocity.dot(wish_dir)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return

	var accel_speed := MC.ACCELERATE * delta * wish_speed
	accel_speed = minf(accel_speed, add_speed)

	velocity.x += accel_speed * wish_dir.x
	velocity.z += accel_speed * wish_dir.z

func _apply_air_acceleration(delta: float) -> void:
	if wish_dir.length() < 0.001:
		return

	# Cap wishspd at 30 u/s (0.762 m/s) for addspeed check
	var wish_spd_capped := minf(wish_speed, MC.AIR_SPEED_CAP)

	var current_speed := velocity.dot(wish_dir)
	var add_speed := wish_spd_capped - current_speed
	if add_speed <= 0.0:
		return

	# accelspeed uses original uncapped wish_speed
	var accel_speed := MC.AIR_ACCELERATE * wish_speed * delta
	accel_speed = minf(accel_speed, add_speed)

	velocity.x += accel_speed * wish_dir.x
	velocity.z += accel_speed * wish_dir.z

func _walk_move(delta: float) -> void:
	var move := Vector3(velocity.x, 0, velocity.z) * delta

	# Try flat move
	var flat_collision := move_and_collide(move)
	if not flat_collision:
		return

	# Slide along the collision surface
	var remainder := flat_collision.get_remainder()
	var normal := flat_collision.get_normal()
	var slide := remainder.slide(normal)

	if slide.length() > 0.001:
		# Try step-up: move up, slide, move down
		var step_up := move_and_collide(Vector3(0, MC.STEP_SIZE, 0))
		var step_up_height := MC.STEP_SIZE
		if step_up:
			step_up_height = MC.STEP_SIZE - step_up.get_remainder().length()

		var step_slide := move_and_collide(slide)

		# Step back down
		var step_down := move_and_collide(Vector3(0, -step_up_height, 0))
		if step_down and step_down.get_normal().y >= MC.FLOOR_NORMAL_MIN:
			return  # successful step-up

		# Step-up failed, just do the flat slide
		move_and_collide(Vector3(0, -step_up_height, 0))

	# Final flat slide attempt
	if slide.length() > 0.001:
		move_and_collide(slide)

func _fly_move(delta: float) -> void:
	var move := velocity * delta

	var collision := move_and_collide(move)
	if not collision:
		return

	# Slide along collision surface
	var remainder := collision.get_remainder()
	var normal := collision.get_normal()
	var slide := remainder.slide(normal)

	# Adjust velocity to slide along wall
	velocity = velocity.slide(normal)

	if slide.length() > 0.001:
		var collision2 := move_and_collide(slide)
		if collision2:
			velocity = velocity.slide(collision2.get_normal())
