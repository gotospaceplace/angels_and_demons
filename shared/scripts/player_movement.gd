extends CharacterBody3D

const MC := preload("res://shared/scripts/movement_constants.gd")
var MOUSE_SENSITIVITY: float:
	get: return GameSettings.mouse_sensitivity

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
var test_driven := false

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

# Bullet tagging
var tag_base_cap: float = 0.0
var tag_timer: float = 0.0

# Flash effect
var _flash_overlay: CanvasLayer = null
var _flash_blind: float = 0.0
var _flash_fade: float = 0.0
var _flash_fade_total: float = 0.0

func _ready() -> void:
	if not test_driven:
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

	# Weapon system (child node)
	var ws := Node.new()
	ws.name = "WeaponSystem"
	ws.set_script(preload("res://shared/scripts/weapon_system.gd"))
	add_child(ws)

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
	simulate_tick(delta)


func simulate_tick(delta: float) -> void:
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

	if not on_ground:
		velocity.y -= MC.GRAVITY * delta * 0.5
	else:
		velocity.y = 0.0

	if tag_timer > 0.0:
		tag_timer -= delta
		if tag_timer <= 0.0:
			tag_timer = 0.0
		else:
			var decay := 1.0 - (tag_timer / MC.TAG_RECOVERY_TIME)
			var current_cap := lerpf(tag_base_cap, max_speed, decay)
			var h_vel := Vector3(velocity.x, 0, velocity.z)
			var h_speed := h_vel.length()
			if h_speed > current_cap:
				var scale_f := current_cap / h_speed
				velocity.x *= scale_f
				velocity.z *= scale_f

	scroll_jump_queued = false

	if not test_driven and has_node("/root/SoundManager"):
		var h_speed := Vector3(velocity.x, 0, velocity.z).length()
		SoundManager.update_footsteps(delta, on_ground, h_speed, on_ladder)

func _read_input() -> void:
	if test_driven:
		return

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
	var move := Vector3(velocity.x, 0, velocity.z) * delta

	# Skip the lift-move-snap cycle when not moving. At geometry edges
	# (stair lips, CSG seams) the snap probe returns subtly different
	# travel each frame, producing visible micro-jitter when idle.
	if move.length_squared() < 0.000001:
		return

	var on_slope := ground_normal.y < 0.93 and ground_normal.y >= MC.FLOOR_NORMAL_MIN
	global_position.y += 0.1

	var did_step := false
	var pre_move := global_position
	var flat_collision := move_and_collide(move)
	if flat_collision:
		var remainder := flat_collision.get_remainder()
		var normal := flat_collision.get_normal()

		# Attempt step-up on any collision while on flat ground.
		# Unconditional on normal.y because the ducked capsule (mostly
		# hemisphere) produces high-Y normals even against vertical stair
		# faces. The height-gain and step-down checks prevent false
		# positives against walls and slopes.
		if not on_slope:
			var pre_step_pos := global_position

			var step_up_col := move_and_collide(Vector3(0, MC.STEP_SIZE, 0))
			var step_up_height := MC.STEP_SIZE
			if step_up_col:
				step_up_height -= step_up_col.get_remainder().length()

			if step_up_height > 0.001:
				var fwd_dir := move.normalized()
				var fwd_dist := maxf(remainder.length(), 0.4)
				move_and_collide(fwd_dir * fwd_dist)

				var step_down_col := move_and_collide(Vector3(0, -step_up_height, 0), false, 0.001, false, 4)
				if step_down_col:
					for i in step_down_col.get_collision_count():
						if step_down_col.get_normal(i).y >= MC.FLOOR_NORMAL_MIN:
							var net_height := global_position.y - pre_step_pos.y
							if net_height > 0.02:
								did_step = true
							break

			if not did_step:
				global_position = pre_step_pos

		if not did_step:
			var slide: Vector3
			if normal.y < MC.FLOOR_NORMAL_MIN:
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

	# Ground snap: test_only probe to find walkable surface, then set
	# position directly.  Non-test_only snap caused collision recovery
	# oscillation (recovery pushes up, snap pulls down = visible jitter).
	if not did_step:
		var snap_dist := MC.STEP_SIZE + 0.2
		var snap_test := move_and_collide(Vector3(0, -snap_dist, 0), true, 0.001, false, 4)
		var snapped := false
		if snap_test:
			for i in snap_test.get_collision_count():
				if snap_test.get_normal(i).y >= MC.FLOOR_NORMAL_MIN:
					global_position += snap_test.get_travel()
					snapped = true
					break
		if not snapped:
			# No walkable ground below — undo the lift
			global_position.y -= 0.1

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

	var look_fwd := -head.global_transform.basis.z
	var body_fwd := -global_transform.basis.z
	body_fwd.y = 0.0
	body_fwd = body_fwd.normalized()
	var right_v := global_transform.basis.x
	right_v.y = 0.0
	right_v = right_v.normalized()

	var wish_vel := Vector3.ZERO
	if wish_speed > 0.001:
		var fwd_amt := wish_dir.dot(body_fwd)
		var side_amt := wish_dir.dot(right_v)
		wish_vel = look_fwd * fwd_amt + right_v * side_amt

	# Dismount if pushing away from ladder face
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


func apply_bullet_tag(weapon_max_speed: float) -> void:
	var h_vel := Vector3(velocity.x, 0, velocity.z)
	var h_speed := h_vel.length()

	var cap: float
	if hop_count > 0 and h_speed > max_speed * 1.1:
		cap = weapon_max_speed * MC.TAG_BHOP_MULTIPLIER
	else:
		cap = weapon_max_speed

	if h_speed > cap:
		var scale_f := cap / h_speed
		velocity.x *= scale_f
		velocity.z *= scale_f

	tag_base_cap = cap
	tag_timer = MC.TAG_RECOVERY_TIME


func apply_flash(blind_time: float, fade_time: float) -> void:
	if not _flash_overlay:
		_flash_overlay = CanvasLayer.new()
		_flash_overlay.layer = 100
		var rect := ColorRect.new()
		rect.name = "Rect"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.color = Color(1, 1, 1, 0)
		_flash_overlay.add_child(rect)
		add_child(_flash_overlay)
	_flash_blind = blind_time
	_flash_fade = fade_time
	_flash_fade_total = fade_time
	_flash_overlay.get_node("Rect").color = Color(1, 1, 1, 1)
	_flash_overlay.visible = true


func _process(delta: float) -> void:
	if _flash_overlay and _flash_overlay.visible:
		if _flash_blind > 0.0:
			_flash_blind -= delta
		elif _flash_fade > 0.0:
			_flash_fade -= delta
			var alpha := _flash_fade / _flash_fade_total if _flash_fade_total > 0.0 else 0.0
			_flash_overlay.get_node("Rect").color = Color(1, 1, 1, maxf(alpha, 0.0))
		else:
			_flash_overlay.visible = false


func apply_network_input(yaw_deg: float, pitch_deg: float,
		fwd: bool, back: bool, left: bool, right_btn: bool,
		jump: bool, duck: bool) -> void:
	rotation.y = deg_to_rad(yaw_deg)
	head.rotation.x = clampf(deg_to_rad(pitch_deg), -PI / 2.0, PI / 2.0)

	var forward := -global_transform.basis.z
	var right_v := global_transform.basis.x
	forward.y = 0.0
	right_v.y = 0.0
	forward = forward.normalized()
	right_v = right_v.normalized()

	var input_v := Vector2.ZERO
	if left: input_v.x -= 1.0
	if right_btn: input_v.x += 1.0
	if fwd: input_v.y -= 1.0
	if back: input_v.y += 1.0
	if input_v.length_squared() > 1.0:
		input_v = input_v.normalized()

	var wish_vel := forward * (-input_v.y) + right_v * input_v.x
	wish_speed = wish_vel.length() * max_speed
	if wish_vel.length() > 0.001:
		wish_dir = wish_vel.normalized()
	else:
		wish_dir = Vector3.ZERO

	jump_was_pressed = jump_pressed
	jump_pressed = jump
	wants_duck = duck
