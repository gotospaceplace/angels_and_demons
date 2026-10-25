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

var scroll_jump_queued := false

# Ducking
var is_ducked := false
var wants_duck := false
var duck_eye_progress := 0.0

# Bhop tracking
var hop_count := 0
var ground_time := 0.0

# Ground surface
var ground_normal := Vector3.UP

# Ladder
var on_ladder := false
var ladder_normal := Vector3.FORWARD
var _ladder_area: Area3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	add_to_group("player")
	standing_collision.shape = standing_collision.shape.duplicate()
	var capsule: CapsuleShape3D = standing_collision.shape
	capsule.height = MC.HULL_STANDING_HEIGHT

	_ladder_area = Area3D.new()
	_ladder_area.collision_layer = 0
	_ladder_area.collision_mask = 2
	var ladder_shape := CollisionShape3D.new()
	var ladder_capsule := CapsuleShape3D.new()
	ladder_capsule.radius = capsule.radius
	ladder_capsule.height = capsule.height
	ladder_shape.shape = ladder_capsule
	_ladder_area.add_child(ladder_shape)
	add_child(_ladder_area)
	_ladder_area.area_entered.connect(_on_ladder_entered)
	_ladder_area.area_exited.connect(_on_ladder_exited)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -PI / 2.0, PI / 2.0)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.is_action_pressed("jump"):
		scroll_jump_queued = true

func _physics_process(delta: float) -> void:
	_read_input()
	_handle_ducking(delta)

	if is_ducked:
		wish_speed *= MC.DUCKING_MULTIPLIER

	if on_ladder:
		_ladder_move(delta)
		scroll_jump_queued = false
		return

	_categorize_position()

	if on_ground:
		ground_time += delta
	else:
		ground_time = 0.0

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

	scroll_jump_queued = false

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
	wants_duck = Input.is_action_pressed("duck")

func _handle_ducking(delta: float) -> void:
	if wants_duck and not is_ducked:
		_do_duck()
	elif not wants_duck and is_ducked:
		_try_unduck()

	var target := 1.0 if is_ducked else 0.0
	if on_ground:
		if duck_eye_progress < target:
			duck_eye_progress = minf(duck_eye_progress + delta / MC.DUCK_TIME, target)
		elif duck_eye_progress > target:
			duck_eye_progress = maxf(duck_eye_progress - delta / MC.DUCK_TIME, target)
	else:
		duck_eye_progress = target

	head.position.y = lerpf(MC.VIEW_OFFSET_STANDING, MC.VIEW_OFFSET_DUCKING, duck_eye_progress)

func _do_duck() -> void:
	is_ducked = true
	var capsule: CapsuleShape3D = standing_collision.shape
	capsule.height = MC.HULL_DUCKING_HEIGHT

	if on_ground:
		var height_diff := MC.HULL_STANDING_HEIGHT * 0.5 - MC.HULL_DUCKING_HEIGHT * 0.5
		global_position.y -= height_diff

func _try_unduck() -> void:
	if not _can_unduck():
		return

	is_ducked = false
	var capsule: CapsuleShape3D = standing_collision.shape
	capsule.height = MC.HULL_STANDING_HEIGHT

	if on_ground:
		var height_diff := MC.HULL_STANDING_HEIGHT * 0.5 - MC.HULL_DUCKING_HEIGHT * 0.5
		global_position.y += height_diff

func _can_unduck() -> bool:
	if not on_ground:
		return true

	var half_ducked := MC.HULL_DUCKING_HEIGHT * 0.5
	var extra := MC.HULL_STANDING_HEIGHT - MC.HULL_DUCKING_HEIGHT

	var space_state := get_world_3d().direct_space_state
	var top := global_position + Vector3(0, half_ducked, 0)
	var params := PhysicsRayQueryParameters3D.create(top, top + Vector3(0, extra, 0))
	params.exclude = [get_rid()]
	var result: Dictionary = space_state.intersect_ray(params)
	return result.is_empty()

func _categorize_position() -> void:
	was_on_ground = on_ground

	if velocity.y > 0.0:
		on_ground = false
		ground_normal = Vector3.UP
		return

	# test_only probe: detect ground without moving the capsule.
	# max_collisions=4 so we find the walkable floor even when the
	# hemisphere also clips a nearby steep surface.
	var probe := move_and_collide(Vector3(0, -0.1, 0), true, 0.001, false, 4)
	if probe:
		for i in probe.get_collision_count():
			if probe.get_normal(i).y >= MC.FLOOR_NORMAL_MIN:
				on_ground = true
				ground_normal = probe.get_normal(i)
				return

	on_ground = false
	ground_normal = Vector3.UP

func _ground_move(delta: float) -> void:
	# Pre-move half gravity
	velocity.y -= MC.GRAVITY * delta * 0.5
	velocity.y = 0.0

	var keyboard_jump := jump_pressed and not jump_was_pressed
	if (keyboard_jump or scroll_jump_queued) and on_ground:
		if ground_time < MC.BHOP_WINDOW:
			hop_count += 1
		else:
			hop_count = 0

		if hop_count > MC.BHOP_FREE_HOPS:
			var speed_factor := maxf(1.0 - float(hop_count - MC.BHOP_FREE_HOPS) * MC.BHOP_DEGRADATION_RATE, MC.BHOP_MIN_SPEED_FACTOR)
			var speed_cap := max_speed * speed_factor
			var h_speed := Vector3(velocity.x, 0, velocity.z).length()
			if h_speed > speed_cap:
				var scale_f := speed_cap / h_speed
				velocity.x *= scale_f
				velocity.z *= scale_f

		velocity.y = MC.JUMP_SPEED
		on_ground = false
		scroll_jump_queued = false
		return

	# Friction
	_apply_friction(delta)

	# Ground acceleration
	_apply_ground_acceleration(delta)

	# Clamp horizontal ground speed
	var h_speed := Vector3(velocity.x, 0, velocity.z).length()
	if h_speed > MC.GROUND_SPEED_CLAMP:
		var scale_f := MC.GROUND_SPEED_CLAMP / h_speed
		velocity.x *= scale_f
		velocity.z *= scale_f

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
		start + Vector3(0, -(MC.HULL_DUCKING_HEIGHT if is_ducked else MC.HULL_STANDING_HEIGHT) * 0.5 - MC.GROUND_TRACE_DIST, 0)
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
	var on_slope := ground_normal.y < 0.99 and ground_normal.y >= MC.FLOOR_NORMAL_MIN
	if on_slope:
		move_and_collide(Vector3(0, 0.08, 0))

	var move := Vector3(velocity.x, 0, velocity.z) * delta

	var did_step := false
	var flat_collision := move_and_collide(move)
	if flat_collision:
		var remainder := flat_collision.get_remainder()
		var normal := flat_collision.get_normal()

		# Step-up only for near-vertical walls (|normal.y| < 0.3).
		# Steep slopes, ramp undersides and base faces all have larger
		# |normal.y| and the up/forward/down sequence traps the capsule.
		if not on_slope and absf(normal.y) < 0.3:
			var pre_step_pos := global_position

			var step_up_col := move_and_collide(Vector3(0, MC.STEP_SIZE, 0))
			var step_up_height := MC.STEP_SIZE
			if step_up_col:
				step_up_height -= step_up_col.get_remainder().length()

			if step_up_height > 0.001:
				var fwd_dir := move.normalized()
				var fwd_dist := maxf(remainder.length(), 0.4)
				move_and_collide(fwd_dir * fwd_dist)

				var step_down_col := move_and_collide(Vector3(0, -step_up_height, 0))
				if step_down_col and step_down_col.get_normal().y >= MC.FLOOR_NORMAL_MIN:
					did_step = true

			if not did_step:
				global_position = pre_step_pos

		if not did_step:
			var slide: Vector3
			if normal.y < MC.FLOOR_NORMAL_MIN:
				# Any non-walkable surface (steep slopes, ramp base faces,
				# undersides): project normal to horizontal and treat as a
				# vertical wall.  Direct position offset avoids re-collision
				# from capsule hemisphere proximity.
				var wall_n := Vector3(normal.x, 0, normal.z)
				if wall_n.length() > 0.001:
					wall_n = wall_n.normalized()
					slide = remainder.slide(wall_n)
				else:
					slide = remainder
				slide.y = 0.0
				if slide.length() > 0.001:
					global_position += slide
			else:
				slide = remainder.slide(normal)
				if slide.y > 0.0:
					slide.y = 0.0
				if slide.length() > 0.001:
					move_and_collide(slide)

	# Ground snap: trace down to maintain slope and stair contact.
	# max_collisions=4 so the snap finds the walkable floor even when the
	# capsule hemisphere also clips a nearby steep surface.
	if not did_step:
		var pre_snap := global_position
		var snap_col := move_and_collide(Vector3(0, -(MC.STEP_SIZE + 0.1), 0), false, 0.001, false, 4)
		var snap_ok := false
		if snap_col:
			for i in snap_col.get_collision_count():
				if snap_col.get_normal(i).y >= MC.FLOOR_NORMAL_MIN:
					snap_ok = true
					break
		if not snap_ok:
			global_position = pre_snap

func _fly_move(delta: float) -> void:
	var start_y := global_position.y
	var move := velocity * delta
	var hit_steep := false
	var steep_normal := Vector3.ZERO

	var collision := move_and_collide(move)
	if not collision:
		return

	var remainder := collision.get_remainder()
	var normal := collision.get_normal()
	var slide := remainder.slide(normal)

	velocity = velocity.slide(normal)
	if normal.y > 0.0 and normal.y < MC.FLOOR_NORMAL_MIN:
		hit_steep = true
		steep_normal = normal
		if velocity.y > 0.0:
			velocity.y = 0.0
	if slide.y > 0.0:
		slide.y = 0.0

	if slide.length() > 0.001:
		var collision2 := move_and_collide(slide)
		if collision2:
			velocity = velocity.slide(collision2.get_normal())
			if collision2.get_normal().y > 0.0 and collision2.get_normal().y < MC.FLOOR_NORMAL_MIN:
				hit_steep = true
				steep_normal = collision2.get_normal()
				if velocity.y > 0.0:
					velocity.y = 0.0

	if hit_steep:
		velocity.y = minf(velocity.y, 0.0)
		# Only clamp Y when the player is actively pressing into the slope.
		# Without this condition the clamp traps the player inside the ramp:
		# collision recovery pushes up+away, clamp undoes the "up", leaving
		# the capsule embedded, and every subsequent move_and_collide re-collides.
		if global_position.y > start_y:
			var horiz_n := Vector3(steep_normal.x, 0, steep_normal.z)
			if horiz_n.length() > 0.001:
				horiz_n = horiz_n.normalized()
				if wish_dir.dot(-horiz_n) > 0.3:
					global_position.y = start_y

func _ladder_move(delta: float) -> void:
	var keyboard_jump := jump_pressed and not jump_was_pressed
	if keyboard_jump or scroll_jump_queued:
		on_ladder = false
		velocity = ladder_normal * MC.JUMP_SPEED
		velocity.y = MC.JUMP_SPEED
		on_ground = false
		scroll_jump_queued = false
		return

	var climb_speed := MC.MAX_CLIMB_SPEED
	if is_ducked:
		climb_speed *= MC.DUCKING_MULTIPLIER

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var cam_forward := -camera.global_transform.basis.z
	var right := global_transform.basis.x

	var wish_vel := cam_forward * (-input_dir.y) + right * input_dir.x

	# Dismount if pushing away from ladder face (pressing S while facing wall)
	if wish_vel.dot(ladder_normal) > 0.5:
		on_ladder = false
		velocity = ladder_normal * MC.MAX_CLIMB_SPEED * 0.5
		return

	# Project out the ladder normal, then re-normalize to preserve full climb speed
	wish_vel = wish_vel - ladder_normal * wish_vel.dot(ladder_normal)
	if wish_vel.length() > 0.001:
		wish_vel = wish_vel.normalized()
	else:
		wish_vel = Vector3.ZERO

	velocity = wish_vel * climb_speed

	var move := velocity * delta
	var collision := move_and_collide(move)
	if collision:
		var remainder := collision.get_remainder()
		var slide := remainder.slide(collision.get_normal())
		velocity = velocity.slide(collision.get_normal())
		if slide.length() > 0.001:
			move_and_collide(slide)

func _on_ladder_entered(area: Area3D) -> void:
	if area is LadderVolume:
		on_ladder = true
		ladder_normal = area.face_normal
		ground_time = 0.0

func _on_ladder_exited(area: Area3D) -> void:
	if area is LadderVolume:
		on_ladder = false
		velocity.y = 0.0
