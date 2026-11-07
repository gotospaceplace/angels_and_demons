extends RefCounted

const MC = preload("res://shared/scripts/movement_constants.gd")
const WC = preload("res://shared/scripts/weapon_constants.gd")
const WR = preload("res://shared/scripts/weapon_registry.gd")

const HISTORY_SIZE := 32
const INTERP_TICKS := 13
const HEAD_HALF := Vector3(0.10, 0.11, 0.10)
const HEAD_STANDING := Vector3(0.0, 1.618, -0.022)
const HEAD_CROUCHED := Vector3(0.0, 1.160, -0.141)
const BODY_RADIUS := 0.35

var history: Array = []
var weapons: Array = []


func _init() -> void:
	weapons = WR.create_all()


func store_tick(tick: int, players: Dictionary) -> void:
	var entry := {"tick": tick, "players": {}}
	for pid in players:
		var sp = players[pid]
		if sp.is_dead:
			continue
		entry["players"][pid] = {
			"position": sp.body.global_position,
			"duck_fraction": sp.body.duck_fraction,
			"yaw": sp.body.rotation.y,
		}
	history.append(entry)
	if history.size() > HISTORY_SIZE:
		history.pop_front()


func get_weapon(idx: int):
	if idx >= 0 and idx < weapons.size():
		return weapons[idx]
	return weapons[2]


func process_fire(shooter_id: int, cmd: NetInput, current_tick: int,
		players: Dictionary, space: PhysicsDirectSpaceState3D,
		is_stab: bool = false) -> Dictionary:
	var shooter_sp = players.get(shooter_id)
	if not shooter_sp or shooter_sp.is_dead:
		return {}

	var rewind_tick := cmd.tick - INTERP_TICKS
	var min_tick := current_tick - NetConstants.MAX_REWIND_TICKS
	rewind_tick = maxi(rewind_tick, min_tick)

	var state := _find_closest_state(rewind_tick)
	if state.is_empty():
		return {}

	var shooter_duck: float = shooter_sp.body.duck_fraction
	var eye_offset: float = lerpf(MC.VIEW_OFFSET_STANDING, MC.VIEW_OFFSET_DUCKING, shooter_duck)
	var eye_pos: Vector3 = shooter_sp.body.global_position + Vector3(0, eye_offset, 0)

	var yaw_rad := deg_to_rad(cmd.yaw)
	var pitch_rad := deg_to_rad(cmd.pitch)
	var direction := Vector3(
		-sin(yaw_rad) * cos(pitch_rad),
		sin(pitch_rad),
		-cos(yaw_rad) * cos(pitch_rad)
	).normalized()

	var weapon = get_weapon(shooter_sp.weapon_idx)
	var max_range: float
	if weapon.is_melee:
		max_range = weapon.stab_range if is_stab else weapon.melee_range
	else:
		max_range = WC.MAX_HITSCAN_RANGE / MC.UNITS_PER_METER

	var world_dist := max_range
	var params := PhysicsRayQueryParameters3D.create(
		eye_pos, eye_pos + direction * max_range)
	params.collision_mask = 1
	var excludes: Array[RID] = [shooter_sp.body.get_rid()]
	for sp in players.values():
		excludes.append(sp.body.get_rid())
	params.exclude = excludes
	var world_result := space.intersect_ray(params)
	if world_result:
		world_dist = eye_pos.distance_to(world_result["position"])

	var pen_depth: float = WC.PEN_MAX_DEPTH.get(weapon.penetration_level, 0.0)
	var scan_dist: float = world_dist + pen_depth if pen_depth > 0.0 else world_dist

	var best_hit := {}
	var best_dist := scan_dist

	var check_states: Dictionary = {}
	for pid in state["players"]:
		check_states[pid] = state["players"][pid]
	for pid in players:
		if pid in check_states:
			continue
		var sp = players[pid]
		if sp.is_dead:
			continue
		check_states[pid] = {
			"position": sp.body.global_position,
			"duck_fraction": sp.body.duck_fraction,
			"yaw": sp.body.rotation.y,
		}

	for pid in check_states:
		if pid == shooter_id:
			continue
		if not players.has(pid):
			continue

		var ps: Dictionary = check_states[pid]
		var target_pos: Vector3 = ps["position"]
		var duck_frac: float = ps["duck_fraction"]
		var eased: float = duck_frac * duck_frac * (3.0 - 2.0 * duck_frac)
		var target_yaw: float = ps["yaw"]

		var hull_h: float = lerpf(MC.HULL_STANDING_HEIGHT, MC.HULL_DUCKING_HEIGHT, eased)
		var feet_pos: Vector3 = target_pos - Vector3(0, hull_h * 0.5, 0)

		var head_local: Vector3 = HEAD_STANDING.lerp(HEAD_CROUCHED, eased)
		var yaw_basis := Basis(Vector3.UP, target_yaw)
		var head_world: Vector3 = feet_pos + yaw_basis * head_local

		var body_h: float = head_world.y - feet_pos.y - HEAD_HALF.y
		var body_center: Vector3 = feet_pos + Vector3(0, body_h * 0.5, 0)

		var head_t := _ray_box_hit(eye_pos, direction, head_world, HEAD_HALF)
		var body_t := _ray_capsule_vertical(eye_pos, direction, body_center, body_h, BODY_RADIUS)

		var t := -1.0
		var headshot := false
		var hitgroup := ""

		if head_t > 0.0 and head_t < best_dist:
			if body_t <= 0.0 or head_t <= body_t:
				t = head_t
				headshot = true
				hitgroup = "head"
			else:
				t = body_t
		elif body_t > 0.0 and body_t < best_dist:
			t = body_t

		if t <= 0.0 or t >= best_dist:
			continue

		if not headshot:
			var hit_y: float = eye_pos.y + direction.y * t
			var rel_y: float = hit_y - body_center.y
			if rel_y > 0.0:
				hitgroup = "chest"
			elif rel_y > -body_h * 0.15:
				hitgroup = "stomach"
			else:
				hitgroup = "legs"

		best_dist = t
		best_hit = {
			"hit": true,
			"victim_id": pid,
			"hitgroup": hitgroup,
			"headshot": headshot,
			"distance": t,
			"wallbang": t > world_dist,
		}

	if best_hit.is_empty():
		return {}

	var dist_gsrc: float = best_hit["distance"] * MC.UNITS_PER_METER
	var hitgroup_mult: float = WC.HITGROUP_MULTIPLIERS.get(best_hit["hitgroup"], 1.0)
	var range_factor := pow(weapon.range_modifier, dist_gsrc / WC.RANGE_UNIT)

	if weapon.is_melee:
		var victim_id: int = best_hit["victim_id"]
		var victim_ps: Dictionary = check_states.get(victim_id, {})
		var is_backstab := false
		if not victim_ps.is_empty():
			var atk_yaw := deg_to_rad(cmd.yaw)
			var atk_fwd := Vector3(-sin(atk_yaw), 0, -cos(atk_yaw))
			var vic_yaw: float = victim_ps["yaw"]
			var vic_fwd := Vector3(-sin(vic_yaw), 0, -cos(vic_yaw))
			is_backstab = atk_fwd.dot(vic_fwd) > 0.0
		best_hit["backstab"] = is_backstab
		var base_dmg: float
		if is_stab:
			base_dmg = weapon.backstab_stab_damage if is_backstab else weapon.stab_damage
		else:
			base_dmg = weapon.backstab_damage if is_backstab else weapon.base_damage
		best_hit["damage"] = base_dmg * hitgroup_mult
	else:
		var retention: float = 1.0
		if best_hit["wallbang"]:
			retention = WC.WALL_PEN_RETENTION.get(weapon.penetration_level, 0.0)
		best_hit["damage"] = weapon.base_damage * range_factor * hitgroup_mult * retention
	best_hit["weapon_idx"] = shooter_sp.weapon_idx

	return best_hit


func _find_closest_state(target_tick: int) -> Dictionary:
	var best := {}
	var best_diff := 999999
	for entry in history:
		var diff := absi(entry["tick"] - target_tick)
		if diff < best_diff:
			best_diff = diff
			best = entry
	return best


static func _ray_box_hit(origin: Vector3, dir: Vector3,
		center: Vector3, half: Vector3) -> float:
	var lo := -INF
	var hi := INF
	for i in range(3):
		if absf(dir[i]) < 0.0000001:
			if absf(origin[i] - center[i]) > half[i]:
				return -1.0
		else:
			var a: float = (center[i] - half[i] - origin[i]) / dir[i]
			var b: float = (center[i] + half[i] - origin[i]) / dir[i]
			lo = maxf(lo, minf(a, b))
			hi = minf(hi, maxf(a, b))
	if lo > hi or hi <= 0.001:
		return -1.0
	return lo if lo > 0.001 else hi


static func _ray_capsule_vertical(origin: Vector3, dir: Vector3,
		cap_center: Vector3, height: float, radius: float) -> float:
	var half_h := height * 0.5
	var cy_bottom := cap_center.y - half_h + radius
	var cy_top := cap_center.y + half_h - radius
	var cx := cap_center.x
	var cz := cap_center.z

	var best_t := -1.0

	var dx := origin.x - cx
	var dz := origin.z - cz
	var a := dir.x * dir.x + dir.z * dir.z
	var b_val := 2.0 * (dx * dir.x + dz * dir.z)
	var c := dx * dx + dz * dz - radius * radius

	if a > 0.00001:
		var disc := b_val * b_val - 4.0 * a * c
		if disc >= 0:
			var sqrt_d := sqrt(disc)
			var t1 := (-b_val - sqrt_d) / (2.0 * a)
			var t2 := (-b_val + sqrt_d) / (2.0 * a)
			for t in [t1, t2]:
				if t > 0.001:
					var hit_y: float = origin.y + dir.y * float(t)
					if hit_y >= cy_bottom and hit_y <= cy_top:
						if best_t < 0 or t < best_t:
							best_t = t

	var bottom_center := Vector3(cx, cy_bottom, cz)
	var top_center := Vector3(cx, cy_top, cz)

	var tb := _ray_sphere_hit(origin, dir, bottom_center, radius)
	if tb > 0.001:
		var hit_y_b: float = origin.y + dir.y * tb
		if hit_y_b <= cy_bottom:
			if best_t < 0 or tb < best_t:
				best_t = tb

	var tt := _ray_sphere_hit(origin, dir, top_center, radius)
	if tt > 0.001:
		var hit_y_t: float = origin.y + dir.y * tt
		if hit_y_t >= cy_top:
			if best_t < 0 or tt < best_t:
				best_t = tt

	return best_t


static func _ray_sphere_hit(origin: Vector3, dir: Vector3,
		center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b_val := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b_val * b_val - c
	if disc < 0:
		return -1.0
	var sqrt_d := sqrt(disc)
	var t := -b_val - sqrt_d
	if t < 0.001:
		t = -b_val + sqrt_d
	if t < 0.001:
		return -1.0
	return t
