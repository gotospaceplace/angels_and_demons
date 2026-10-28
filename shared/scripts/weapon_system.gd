extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")
const WR := preload("res://shared/scripts/weapon_registry.gd")
const GrenadeProjectile := preload("res://shared/scripts/grenade_projectile.gd")

var player: CharacterBody3D
var camera: Camera3D
var head: Node3D

# Inventory
var weapons: Array = []
var current_index: int = 0
var current = null  # WeaponData resource

# Ammo (parallel arrays indexed by weapon)
var magazine: Array[int] = []
var reserve: Array[int] = []

# Timing
var next_fire_time: float = 0.0
var next_action_time: float = 0.0
var is_reloading: bool = false
var is_switching: bool = false

# Accuracy state
var accuracy: float = 0.0
var shots_fired: int = 0
var last_fire_time: float = 0.0

# Recoil
var viewpunch := Vector2.ZERO
var recoil_shots: int = 0
var lateral_dir: float = 1.0

# Weapon switching
var prev_index: int = 0

# Input
var fire_held: bool = false
var fire_queued: bool = false

# Scope
var is_scoped: bool = false
var zoom_level: int = 0  # 0=none, 1=first zoom, 2=second zoom
var next_scope_time: float = 0.0
const SCOPE_CYCLE_DELAY := 0.3

# Silencer
var silencer_on: bool = false
var is_toggling: bool = false

# Grenades
var grenade_he_count: int = 1
var grenade_flash_count: int = 2
var grenade_smoke_count: int = 1
var current_grenade: int = 0  # 0=HE, 1=Flash, 2=Smoke
var is_grenade_mode: bool = false
var is_cooking: bool = false
var cook_timer: float = 0.0
var cook_short_toss: bool = false

# Telemetry: last hit
var last_hit_group: String = ""
var last_hit_damage: float = 0.0
var last_hit_distance: float = 0.0
var last_hit_weapon: String = ""
var last_hit_timer: float = 0.0
var damage_dealt_log: Array[float] = []
var damage_time_log: Array[float] = []


func _ready() -> void:
	add_to_group("weapon_system")
	player = get_parent() as CharacterBody3D
	head = player.get_node("Head")
	camera = player.get_node("Head/Camera3D")
	weapons = WR.create_all()
	for w in weapons:
		magazine.append(w.magazine_size)
		reserve.append(w.reserve_ammo)
	_equip(0)
	player.max_speed = current.max_speed


func _unhandled_input(event: InputEvent) -> void:
	if player.test_driven:
		return
	if event.is_action_pressed("weapon_4"):
		_select_grenade()
		return
	if is_grenade_mode:
		_grenade_input(event)
		return
	if event.is_action_pressed("fire"):
		fire_held = true
		fire_queued = true
	if event.is_action_released("fire"):
		fire_held = false
	if event.is_action_pressed("fire_secondary"):
		_secondary_action()
	if event.is_action_pressed("reload"):
		_start_reload()
	if event.is_action_pressed("weapon_1"):
		_switch_to_slot(2)  # primary (AK/M4/AWP)
	if event.is_action_pressed("weapon_2"):
		_switch_to_slot(1)  # pistol (USP)
	if event.is_action_pressed("weapon_3"):
		_switch_to_slot(0)  # knife
	if event.is_action_pressed("weapon_last"):
		_switch_to_last()
	if event.is_action_pressed("weapon_next"):
		_cycle_weapon(1)
	if event.is_action_pressed("weapon_prev"):
		_cycle_weapon(-1)


func _physics_process(delta: float) -> void:
	var now := _now()
	_decay_viewpunch(delta)
	_apply_viewpunch()
	_update_accuracy_recovery(delta, now)

	while damage_time_log.size() > 0 and now - damage_time_log[0] > 5.0:
		damage_time_log.remove_at(0)
		damage_dealt_log.remove_at(0)

	if is_reloading and now >= next_action_time:
		_finish_reload()
	if is_switching and now >= next_action_time:
		is_switching = false
		player.max_speed = current.max_speed
	if is_toggling and now >= next_action_time:
		is_toggling = false
		silencer_on = not silencer_on

	if is_cooking:
		cook_timer -= delta
		if cook_timer <= 0.0:
			_grenade_detonate_in_hand()
		return

	if is_grenade_mode:
		return

	var should_fire := false
	if current.is_automatic:
		should_fire = fire_held
	elif fire_queued:
		should_fire = true
	fire_queued = false

	if should_fire and _can_fire(now):
		_fire(now)


# --- Public interface for crosshair / HUD ---

func get_dps() -> float:
	var total := 0.0
	for d in damage_dealt_log:
		total += d
	if damage_time_log.size() < 2:
		return total
	var span := damage_time_log[damage_time_log.size() - 1] - damage_time_log[0]
	if span <= 0.0:
		return total
	return total / span


func get_current_spread() -> float:
	return _calc_spread()

func get_weapon_name() -> String:
	return current.weapon_name if current else ""

func get_ammo_display() -> String:
	if current.is_melee:
		return ""
	return "%d / %d" % [magazine[current_index], reserve[current_index]]


# --- Core fire logic ---

func _can_fire(now: float) -> bool:
	if is_reloading or is_switching or is_toggling:
		return false
	if now < next_fire_time:
		return false
	if current.is_melee:
		return true
	return magazine[current_index] > 0


func _fire(now: float) -> void:
	next_fire_time = now + current.cycle_time
	last_fire_time = now

	if not current.is_melee:
		magazine[current_index] -= 1

	var spread := _calc_spread()
	var cam_xform := camera.global_transform
	var origin := cam_xform.origin
	var forward := -cam_xform.basis.z
	var right := cam_xform.basis.x
	var up := cam_xform.basis.y

	# Two-random-per-axis spread (bell-curve distribution)
	var x_off := randf_range(-0.5, 0.5) + randf_range(-0.5, 0.5)
	var y_off := randf_range(-0.5, 0.5) + randf_range(-0.5, 0.5)
	var direction := (forward + x_off * spread * right + y_off * spread * up).normalized()

	var max_range: float
	if current.is_melee:
		max_range = current.melee_range
	else:
		max_range = WC.MAX_HITSCAN_RANGE / MC.UNITS_PER_METER

	_trace_bullet(origin, direction, max_range)

	_update_accuracy_after_shot()
	_apply_recoil_kick()

	if not current.is_melee and magazine[current_index] <= 0 and reserve[current_index] > 0:
		_start_reload()


func _trace_bullet(cam_origin: Vector3, direction: Vector3, max_range: float) -> void:
	var pen_left: int = current.penetration_level
	var base_retention: float = WC.WALL_PEN_RETENTION.get(pen_left, 0.0)
	var damage_scale: float = 1.0
	var trace_start := cam_origin
	var space := player.get_world_3d().direct_space_state

	for _i in range(pen_left + 1):
		var remaining := max_range - cam_origin.distance_to(trace_start)
		if remaining <= 0.0:
			return

		var end := trace_start + direction * remaining
		var params := PhysicsRayQueryParameters3D.create(trace_start, end)
		params.exclude = [player.get_rid()]
		params.collide_with_areas = true
		params.collision_mask = 1 | 8  # Layer 1 (World) + Layer 4 (Hitboxes)

		var result := space.intersect_ray(params)
		if not result:
			return

		var collider: Object = result["collider"]
		var hit_pos: Vector3 = result["position"]

		if collider.has_meta("hitgroup"):
			_apply_hit_damage(result, cam_origin, damage_scale)
			if pen_left <= 1 or base_retention <= 0.0:
				return
			trace_start = hit_pos + direction * 0.01
			damage_scale *= base_retention
			pen_left -= 1
			params.exclude.append(collider.get_rid())
			continue

		# Hit world geometry — attempt wall penetration
		if pen_left <= 1 or base_retention <= 0.0:
			return

		var max_depth: float = WC.PEN_MAX_DEPTH.get(pen_left, 0.0)
		if max_depth <= 0.0:
			return

		var exit_pos := _find_wall_exit(hit_pos, direction, max_depth, space)
		if exit_pos == Vector3.ZERO:
			return

		trace_start = exit_pos + direction * 0.01
		damage_scale *= base_retention
		pen_left -= 1


func _find_wall_exit(entry: Vector3, direction: Vector3, max_depth: float, space: PhysicsDirectSpaceState3D) -> Vector3:
	var probe_start := entry + direction * (max_depth + 0.05)
	var params := PhysicsRayQueryParameters3D.create(probe_start, entry)
	params.exclude = [player.get_rid()]
	params.collision_mask = 1  # World only
	var result := space.intersect_ray(params)
	if not result:
		return Vector3.ZERO
	return result["position"]


func _apply_hit_damage(result: Dictionary, cam_origin: Vector3, damage_scale: float) -> void:
	var collider: Object = result["collider"]
	var hit_pos: Vector3 = result["position"]
	var distance_m := cam_origin.distance_to(hit_pos)

	if not collider.has_meta("hitgroup"):
		return

	var hitgroup: String = collider.get_meta("hitgroup")
	var multiplier: float = WC.HITGROUP_MULTIPLIERS.get(hitgroup, 1.0)

	var dmg: float
	if silencer_on and current.has_silencer:
		dmg = current.silenced_damage
	else:
		dmg = current.base_damage

	var rm: float
	if silencer_on and current.has_silencer:
		rm = current.silenced_range_modifier
	else:
		rm = current.range_modifier

	var dist_gsrc := distance_m * MC.UNITS_PER_METER
	var range_factor := pow(rm, dist_gsrc / WC.RANGE_UNIT)
	var final_damage := dmg * range_factor * multiplier * damage_scale

	var target = collider.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(final_damage, hitgroup, current.weapon_name, current.armor_penetration)

	last_hit_group = hitgroup
	last_hit_damage = final_damage
	last_hit_distance = dist_gsrc
	last_hit_weapon = current.weapon_name
	last_hit_timer = 1.0
	var now := _now()
	damage_dealt_log.append(final_damage)
	damage_time_log.append(now)


# --- Spread calculation ---

func _calc_spread() -> float:
	var h_vel := Vector3(player.velocity.x, 0, player.velocity.z)
	var h_speed_gsrc := h_vel.length() * MC.UNITS_PER_METER
	var threshold: float = current.moving_threshold

	var base: float
	var additive: float = 0.0

	if not player.on_ground:
		base = _get_spread_field("airborne")
		additive = current.spread_base_airborne
	elif h_speed_gsrc > threshold and threshold >= 0.0:
		base = _get_spread_field("moving")
		additive = current.spread_base_moving
	elif player.is_ducked:
		base = _get_spread_field("crouching")
	else:
		base = _get_spread_field("standing")

	var spread: float
	match current.accuracy_type:
		0:  # None (fixed)
			spread = base
		1:  # Rifle: multiplier × accuracy
			spread = additive + base * accuracy
		2:  # Pistol: multiplier × (1 - accuracy)
			spread = base * (1.0 - accuracy)
		_:
			spread = base

	# AWP unscoped penalty
	if current.has_scope and not is_scoped:
		spread += WC.AWP_UNSCOPED_SPREAD

	return spread


func _get_spread_field(state: String) -> float:
	if silencer_on and current.has_silencer:
		match state:
			"standing": return current.silenced_spread_standing
			"crouching": return current.silenced_spread_crouching
			"moving": return current.silenced_spread_moving
			"airborne": return current.silenced_spread_airborne
	match state:
		"standing": return current.spread_standing
		"crouching": return current.spread_crouching
		"moving": return current.spread_moving
		"airborne": return current.spread_airborne
	return current.spread_standing


# --- Accuracy ---

func _update_accuracy_after_shot() -> void:
	shots_fired += 1
	match current.accuracy_type:
		1:  # Rifle cubic degradation
			accuracy = (pow(shots_fired, 3) / current.accuracy_divisor) + current.accuracy_offset
			accuracy = minf(accuracy, current.accuracy_cap)
		2:  # Pistol per-shot degrade
			accuracy -= 0.275 * 0.1
			accuracy = clampf(accuracy, 0.6, current.accuracy_deploy)


func _update_accuracy_recovery(delta: float, now: float) -> void:
	if last_fire_time <= 0.0:
		return
	var dt := now - last_fire_time

	match current.accuracy_type:
		1:  # Rifle: recover shots_fired over time
			if dt > 0.4 and shots_fired > 0:
				shots_fired = maxi(shots_fired - 1, 0)
				if shots_fired == 0:
					accuracy = current.accuracy_deploy
				else:
					accuracy = (pow(shots_fired, 3) / current.accuracy_divisor) + current.accuracy_offset
					accuracy = minf(accuracy, current.accuracy_cap)
		2:  # Pistol: recover accuracy over time
			if dt > 0.3:
				accuracy = minf(accuracy + 0.275 * delta, current.accuracy_deploy)


# --- Recoil ---

func _apply_recoil_kick() -> void:
	var params := _get_recoil_params()
	if params.size() < 7:
		return

	recoil_shots += 1
	var up_kick := minf(params[0] + recoil_shots * params[2], params[4])
	var lat_kick := minf(params[1] + recoil_shots * params[3], params[5])
	var dir_change := int(params[6])
	if dir_change > 0 and recoil_shots % dir_change == 0:
		lateral_dir *= -1.0

	viewpunch.x -= deg_to_rad(up_kick)
	viewpunch.y += deg_to_rad(lat_kick) * lateral_dir


func _get_recoil_params() -> PackedFloat64Array:
	var h_speed := Vector3(player.velocity.x, 0, player.velocity.z).length()
	if not player.on_ground:
		return current.recoil_airborne
	if h_speed > MC.INACCURACY_SPEED_THRESHOLD:
		return current.recoil_moving
	if player.is_ducked:
		return current.recoil_crouching
	return current.recoil_standing


func _decay_viewpunch(delta: float) -> void:
	viewpunch *= maxf(0.0, 1.0 - 10.0 * delta)
	if viewpunch.length_squared() < 0.000001:
		viewpunch = Vector2.ZERO


func _apply_viewpunch() -> void:
	camera.rotation.x = viewpunch.x
	camera.rotation.y = viewpunch.y


# --- Weapon switching ---

func _switch_to_slot(slot: int) -> void:
	if is_switching:
		return
	for i in range(weapons.size()):
		if weapons[i].slot == slot and i != current_index:
			_switch_weapon(i)
			return


func _switch_to_last() -> void:
	if is_switching:
		return
	if prev_index != current_index:
		_switch_weapon(prev_index)


func _cycle_weapon(direction: int) -> void:
	if is_switching:
		return
	var next := posmod(current_index + direction, weapons.size())
	if next != current_index:
		_switch_weapon(next)


func _switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	prev_index = current_index
	is_switching = true
	is_reloading = false
	var total_time: float = current.holster_time + weapons[index].draw_time
	next_action_time = _now() + total_time
	_equip(index)


func _equip(index: int) -> void:
	current_index = index
	current = weapons[index]
	accuracy = current.accuracy_deploy
	shots_fired = 0
	recoil_shots = 0
	lateral_dir = 1.0
	is_scoped = false
	zoom_level = 0
	silencer_on = false
	camera.fov = 75.0


# --- Reload ---

func _start_reload() -> void:
	if is_reloading or is_switching or current.is_melee:
		return
	if magazine[current_index] >= current.magazine_size:
		return
	if reserve[current_index] <= 0:
		return
	is_reloading = true
	_unscope()
	next_action_time = _now() + current.reload_time


func _finish_reload() -> void:
	is_reloading = false
	var needed: int = current.magazine_size - magazine[current_index]
	var available: int = mini(needed, reserve[current_index])
	magazine[current_index] += available
	reserve[current_index] -= available
	accuracy = current.accuracy_deploy
	shots_fired = 0
	recoil_shots = 0


# --- Secondary action (scope / silencer toggle) ---

func _secondary_action() -> void:
	if current.has_scope:
		_toggle_scope()
	elif current.has_silencer:
		_toggle_silencer()


func _toggle_silencer() -> void:
	if is_reloading or is_switching or is_toggling:
		return
	is_toggling = true
	next_action_time = _now() + current.silencer_toggle_time


func _toggle_scope() -> void:
	if is_reloading or is_switching or is_toggling:
		return
	var now := _now()
	if now < next_scope_time:
		return
	next_scope_time = now + SCOPE_CYCLE_DELAY
	zoom_level = (zoom_level + 1) % 3
	match zoom_level:
		0:
			is_scoped = false
			camera.fov = 75.0
			player.max_speed = current.max_speed
		1:
			is_scoped = true
			camera.fov = current.zoom_fov_1
			player.max_speed = current.scoped_max_speed
		2:
			is_scoped = true
			camera.fov = current.zoom_fov_2
			player.max_speed = current.scoped_max_speed


func _unscope() -> void:
	if is_scoped:
		is_scoped = false
		zoom_level = 0
		camera.fov = 75.0
		player.max_speed = current.max_speed


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# --- Grenades ---

func _select_grenade() -> void:
	if is_cooking:
		return
	if is_grenade_mode:
		_cycle_grenade()
		return
	if _total_grenades() <= 0:
		return
	is_grenade_mode = true
	is_reloading = false
	is_switching = false
	is_toggling = false
	_unscope()
	player.max_speed = MC.SPEED_KNIFE
	if _grenade_count(current_grenade) <= 0:
		_cycle_grenade()


func _cycle_grenade() -> void:
	var start := current_grenade
	for _i in range(3):
		current_grenade = (current_grenade + 1) % 3
		if _grenade_count(current_grenade) > 0:
			return
	current_grenade = start


func _grenade_count(idx: int) -> int:
	match idx:
		0: return grenade_he_count
		1: return grenade_flash_count
		2: return grenade_smoke_count
	return 0


func _total_grenades() -> int:
	return grenade_he_count + grenade_flash_count + grenade_smoke_count


func _consume_grenade() -> void:
	match current_grenade:
		0: grenade_he_count -= 1
		1: grenade_flash_count -= 1
		2: grenade_smoke_count -= 1


func _get_grenade_name() -> String:
	match current_grenade:
		0: return "HE GRENADE"
		1: return "FLASH"
		2: return "SMOKE"
	return "GRENADE"


func _grenade_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") and not is_cooking:
		_start_cooking(false)
	elif event.is_action_released("fire") and is_cooking and not cook_short_toss:
		_throw_grenade()
	elif event.is_action_pressed("fire_secondary") and not is_cooking:
		_start_cooking(true)
	elif event.is_action_released("fire_secondary") and is_cooking and cook_short_toss:
		_throw_grenade()
	elif not is_cooking:
		if event.is_action_pressed("weapon_1"):
			_exit_grenade_mode()
			_switch_to_slot(2)
		elif event.is_action_pressed("weapon_2"):
			_exit_grenade_mode()
			_switch_to_slot(1)
		elif event.is_action_pressed("weapon_3"):
			_exit_grenade_mode()
			_switch_to_slot(0)
		elif event.is_action_pressed("weapon_last"):
			_exit_grenade_mode()
			_switch_to_last()


func _start_cooking(short: bool) -> void:
	is_cooking = true
	cook_timer = WC.GRENADE_FUSE
	cook_short_toss = short


func _throw_grenade() -> void:
	var cam := camera.global_transform
	var forward := -cam.basis.z
	var spawn_pos := cam.origin + forward * WC.GRENADE_SPAWN_OFFSET

	# Throw angle: small upward bias (5°) for gentle arc
	var view_pitch := rad_to_deg(head.rotation.x)
	var speed_gsrc := (90.0 + view_pitch) * 8.0
	speed_gsrc = clampf(speed_gsrc, 0.0, WC.GRENADE_MAX_VEL_GSRC)
	if cook_short_toss:
		speed_gsrc *= WC.GRENADE_SHORT_TOSS_MULT
	var speed_m := speed_gsrc * MC.METERS_PER_UNIT

	var throw_dir := forward.rotated(cam.basis.x, deg_to_rad(5.0))

	var grenade := RigidBody3D.new()
	grenade.set_script(GrenadeProjectile)
	player.get_parent().add_child(grenade)
	grenade.global_position = spawn_pos
	grenade.linear_velocity = throw_dir * speed_m + player.velocity
	grenade.start(cook_timer, current_grenade)

	_consume_grenade()
	is_cooking = false
	is_grenade_mode = false
	player.max_speed = current.max_speed


func _grenade_detonate_in_hand() -> void:
	var grenade := RigidBody3D.new()
	grenade.set_script(GrenadeProjectile)
	player.get_parent().add_child(grenade)
	grenade.global_position = camera.global_position
	grenade.start(0.0, current_grenade)

	_consume_grenade()
	is_cooking = false
	is_grenade_mode = false
	player.max_speed = current.max_speed


func _exit_grenade_mode() -> void:
	is_grenade_mode = false
	player.max_speed = current.max_speed
