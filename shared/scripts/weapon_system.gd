extends Node

const MC := preload("res://shared/scripts/movement_constants.gd")
const WC := preload("res://shared/scripts/weapon_constants.gd")
const WR := preload("res://shared/scripts/weapon_registry.gd")

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

# Input
var fire_held: bool = false
var fire_queued: bool = false

# Scope
var is_scoped: bool = false
var zoom_level: int = 0  # 0=none, 1=first zoom, 2=second zoom

# Silencer
var silencer_on: bool = false


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


func _unhandled_input(event: InputEvent) -> void:
	if player.test_driven:
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


func _physics_process(delta: float) -> void:
	var now := _now()
	_decay_viewpunch(delta)
	_apply_viewpunch()
	_update_accuracy_recovery(delta, now)

	if is_reloading and now >= next_action_time:
		_finish_reload()
	if is_switching and now >= next_action_time:
		is_switching = false

	var should_fire := false
	if current.is_automatic:
		should_fire = fire_held
	elif fire_queued:
		should_fire = true
	fire_queued = false

	if should_fire and _can_fire(now):
		_fire(now)


# --- Public interface for crosshair / HUD ---

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
	if is_reloading or is_switching:
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

	var end := origin + direction * max_range
	var space := player.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.exclude = [player.get_rid()]
	params.collide_with_areas = true
	params.collision_mask = 1 | 8  # Layer 1 (World) + Layer 4 (Hitboxes)

	var result := space.intersect_ray(params)
	if result:
		_process_hit(result, origin)

	_update_accuracy_after_shot()
	_apply_recoil_kick()

	if not current.is_melee and magazine[current_index] <= 0 and reserve[current_index] > 0:
		_start_reload()


func _process_hit(result: Dictionary, origin: Vector3) -> void:
	var collider: Object = result["collider"]
	var hit_pos: Vector3 = result["position"]
	var distance_m := origin.distance_to(hit_pos)

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
	var final_damage := dmg * range_factor * multiplier

	var target = collider.get_parent()
	if target and target.has_method("take_damage"):
		target.take_damage(final_damage, hitgroup, current.weapon_name, current.armor_penetration)


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


func _switch_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
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
	player.max_speed = current.max_speed


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


func _toggle_scope() -> void:
	if is_reloading or is_switching:
		return
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
